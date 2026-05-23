#!/bin/bash
# Automated Cassandra snapshot backup script
# Usage: ./scripts/cassandra-backup.sh
# Requires: Docker, running Cassandra container
#
# Creates a hard-linked snapshot, copies it to a timestamped backup
# directory, clears the snapshot, and prunes backups older than 7 days.

set -euo pipefail

BACKUP_BASE="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_BASE}/${TIMESTAMP}"
KEYSPACE="url_shortener"
CONTAINER="cassandra"
SNAPSHOT_TAG="auto_backup_$(date +%Y%m%d)"

echo "[$(date +%H:%M:%S)] Starting Cassandra backup for keyspace: $KEYSPACE"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: Cassandra container '$CONTAINER' is not running"
  exit 1
fi

echo "[$(date +%H:%M:%S)] Creating snapshot: $SNAPSHOT_TAG"
docker exec "$CONTAINER" nodetool snapshot -t "$SNAPSHOT_TAG" "$KEYSPACE"

mkdir -p "$BACKUP_DIR"

echo "[$(date +%H:%M:%S)] Copying snapshot files to $BACKUP_DIR..."
docker cp "${CONTAINER}:/var/lib/cassandra/data/${KEYSPACE}" "$BACKUP_DIR/"

echo "[$(date +%H:%M:%S)] Clearing snapshot: $SNAPSHOT_TAG"
docker exec "$CONTAINER" nodetool clearsnapshot -t "$SNAPSHOT_TAG" "$KEYSPACE"

echo "[$(date +%H:%M:%S)] Verifying backup..."
if [ -d "$BACKUP_DIR/$KEYSPACE" ] && [ "$(ls -A "$BACKUP_DIR/$KEYSPACE")" ]; then
  BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
  echo "[$(date +%H:%M:%S)] Backup complete: $BACKUP_DIR ($BACKUP_SIZE)"
else
  echo "ERROR: Backup verification failed - backup directory is empty"
  exit 1
fi

echo "[$(date +%H:%M:%S)] Cleaning up backups older than 7 days..."
find "$BACKUP_BASE" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;
echo "[$(date +%H:%M:%S)] Old backups cleaned"

echo "[$(date +%H:%M:%S)] Backup finished successfully"