#!/bin/bash
# Cassandra snapshot restore script
# Usage: ./scripts/cassandra-restore.sh <backup_directory>
# Example: ./scripts/cassandra-restore.sh /backups/20250101_020000
#
# WARNING: This script DESTROYS existing data in the url_shortener keyspace
# and replaces it with the backup. Run with caution.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <backup_directory>"
  echo "Example: $0 /backups/20250101_020000"
  exit 1
fi

BACKUP_DIR="$1"
KEYSPACE="url_shortener"
CONTAINER="cassandra"
SNAPSHOT_TAG="pre_restore_$(date +%Y%m%d_%H%M%S)"

if [ ! -d "$BACKUP_DIR/$KEYSPACE" ]; then
  echo "ERROR: Backup directory does not contain keyspace '$KEYSPACE'"
  echo "Expected: $BACKUP_DIR/$KEYSPACE"
  exit 1
fi

echo "[$(date +%H:%M:%S)] WARNING: This will destroy and replace all data in keyspace '$KEYSPACE'"
read -rp "Are you sure? (type 'yes' to continue): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Restore cancelled."
  exit 0
fi

echo "[$(date +%H:%M:%S)] Starting restore from: $BACKUP_DIR"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: Cassandra container '$CONTAINER' is not running"
  exit 1
fi

echo "[$(date +%H:%M:%S)] Creating pre-restore safety snapshot..."
docker exec "$CONTAINER" nodetool snapshot -t "$SNAPSHOT_TAG" "$KEYSPACE" || true

echo "[$(date +%H:%M:%S)] Truncating existing tables..."
docker exec "$CONTAINER" cqlsh -e "TRUNCATE ${KEYSPACE}.url_mappings;"
docker exec "$CONTAINER" cqlsh -e "TRUNCATE ${KEYSPACE}.url_metadata;"

echo "[$(date +%H:%M:%S)] Copying backup data into container..."
docker cp "$BACKUP_DIR/$KEYSPACE" "${CONTAINER}:/var/lib/cassandra/data/"

echo "[$(date +%H:%M:%S)] Setting file permissions..."
docker exec "$CONTAINER" chown -R cassandra:cassandra "/var/lib/cassandra/data/$KEYSPACE"

echo "[$(date +%H:%M:%S)] Loading new SSTables..."
TABLE_DIRS=$(docker exec "$CONTAINER" ls "/var/lib/cassandra/data/$KEYSPACE" 2>/dev/null || true)
for DIR in $TABLE_DIRS; do
  TABLE_NAME=$(echo "$DIR" | sed 's/-.*//')
  echo "  Loading SSTables for: $TABLE_NAME"
  docker exec "$CONTAINER" nodetool refresh "$KEYSPACE" "$TABLE_NAME" || true
done

echo "[$(date +%H:%M:%S)] Running repair..."
docker exec "$CONTAINER" nodetool repair "$KEYSPACE" || true

echo "[$(date +%H:%M:%S)] Verifying restore..."
docker exec "$CONTAINER" cqlsh -e "SELECT COUNT(*) FROM ${KEYSPACE}.url_mappings;"

echo "[$(date +%H:%M:%S)] Restore complete"