# Cassandra Backup and Restore

This document describes backup and restore procedures for the `url_shortener` keyspace using Cassandra's `nodetool` snapshot utility.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Snapshot Backup Procedure](#snapshot-backup-procedure)
- [Incremental Backup Strategy](#incremental-backup-strategy)
- [Restore Procedure from Snapshots](#restore-procedure-from-snapshots)
- [Automated Backup Script](#automated-backup-script)
- [Restore Script](#restore-script)
- [Verification](#verification)

---

## Prerequisites

- Cassandra container must be running
- `nodetool` must be accessible via `docker exec cassandra nodetool`
- Sufficient disk space on the host for backup archives
- Destination backup directory must exist (e.g., `/backups`)

---

## Snapshot Backup Procedure

Cassandra snapshots create hard links to SSTable files with zero copy overhead.

### Create a Snapshot

```bash
docker exec cassandra nodetool snapshot -t "backup_YYYYMMDD" url_shortener
```

Parameters:
- `-t "backup_YYYYMMDD"` — unique snapshot tag name
- `url_shortener` — keyspace to back up

### Locate Snapshot Files

Snapshots are stored in each table's data directory:

```
/var/lib/cassandra/data/url_shortener/url_mappings-<uuid>/snapshots/backup_YYYYMMDD/
/var/lib/cassandra/data/url_shortener/url_metadata-<uuid>/snapshots/backup_YYYYMMDD/
```

### Copy Snapshots to Backup Location

```bash
# Copy all table data for the keyspace
docker cp cassandra:/var/lib/cassandra/data/url_shortener /backups/YYYYMMDD_HHMMSS/
```

### Clear Snapshot

After copying, remove the snapshot from Cassandra to free disk space:

```bash
docker exec cassandra nodetool clearsnapshot -t "backup_YYYYMMDD" url_shortener
```

---

## Incremental Backup Strategy

Cassandra supports incremental backups via `incremental_backups` in `cassandra.yaml`.

### Enable Incremental Backups

Set the following in `cassandra.yaml` (or pass via environment variable):

```yaml
incremental_backups: true
```

Or enable at runtime:

```bash
docker exec cassandra nodetool enablebackup
```

### How Incremental Backups Work

- After each memtable flush, new SSTables are hard-linked to a `backups/` subdirectory
- These contain only data written since the last full snapshot
- Combine with weekly full snapshots for a complete recovery chain

### Backup Strategy Recommendation

| Frequency | Type              | Retention     |
|-----------|-------------------|---------------|
| Daily     | Full snapshot     | 7 days        |
| Hourly    | Incremental       | 24 hours      |
| Weekly    | Full snapshot     | 4 weeks       |
| Monthly   | Full snapshot     | 12 months     |

### Automate Incremental Archiving

Use a cron job to rsync incremental backups to a remote location:

```bash
rsync -avz /var/lib/cassandra/data/url_shortener/*/backups/ user@backup-server:/backups/cassandra/incremental/
```

---

## Restore Procedure from Snapshots

### Step 1: Stop Cassandra

```bash
docker stop cassandra
```

### Step 2: Clear Existing Data

```bash
docker exec cassandra rm -rf /var/lib/cassandra/data/url_shortener
```

### Step 3: Restore Snapshot Files

```bash
# Copy backup files into place
docker cp /backups/YYYYMMDD_HHMMSS/url_shortener cassandra:/var/lib/cassandra/data/

# For each table, copy snapshot contents to the table data directory
# The table UUID directories will differ between backups and new instances
```

If the table ID (UUID) has changed, you must copy snapshot contents directly:

```bash
# Find table directories
TABLE_DIRS=$(docker exec cassandra ls /var/lib/cassandra/data/url_shortener/)

for DIR in $TABLE_DIRS; do
  SNAPSHOT_PATH="/var/lib/cassandra/data/url_shortener/$DIR/snapshots/backup_YYYYMMDD"
  if docker exec cassandra [ -d "$SNAPSHOT_PATH" ]; then
    echo "Restoring $DIR..."
    docker exec cassandra cp -r "$SNAPSHOT_PATH"/* "/var/lib/cassandra/data/url_shortener/$DIR/"
  fi
done
```

### Step 4: Set Correct Permissions

```bash
docker exec cassandra chown -R cassandra:cassandra /var/lib/cassandra/data/url_shortener
```

### Step 5: Start Cassandra

```bash
docker start cassandra
```

### Step 6: Run Repair

After restore, run repair to ensure consistency:

```bash
docker exec cassandra nodetool repair url_shortener
```

---

## Automated Backup Script

Location: `scripts/cassandra-backup.sh`

```bash
#!/bin/bash
# Automated Cassandra snapshot backup script
# Usage: ./scripts/cassandra-backup.sh
# Requires: Docker, running Cassandra container

set -euo pipefail

BACKUP_BASE="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_BASE}/${TIMESTAMP}"
KEYSPACE="url_shortener"
CONTAINER="cassandra"
SNAPSHOT_TAG="auto_backup_$(date +%Y%m%d)"

echo "[$(date +%H:%M:%S)] Starting Cassandra backup for keyspace: $KEYSPACE"

# Verify container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: Cassandra container '$CONTAINER' is not running"
  exit 1
fi

# Create snapshot
echo "[$(date +%H:%M:%S)] Creating snapshot: $SNAPSHOT_TAG"
docker exec "$CONTAINER" nodetool snapshot -t "$SNAPSHOT_TAG" "$KEYSPACE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Copy snapshot files
echo "[$(date +%H:%M:%S)] Copying snapshot files to $BACKUP_DIR..."
docker cp "${CONTAINER}:/var/lib/cassandra/data/${KEYSPACE}" "$BACKUP_DIR/"

# Clear snapshot from Cassandra
echo "[$(date +%H:%M:%S)] Clearing snapshot: $SNAPSHOT_TAG"
docker exec "$CONTAINER" nodetool clearsnapshot -t "$SNAPSHOT_TAG" "$KEYSPACE"

# Verify backup integrity
echo "[$(date +%H:%M:%S)] Verifying backup..."
if [ -d "$BACKUP_DIR/$KEYSPACE" ] && [ "$(ls -A "$BACKUP_DIR/$KEYSPACE")" ]; then
  BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
  echo "[$(date +%H:%M:%S)] Backup complete: $BACKUP_DIR ($BACKUP_SIZE)"
else
  echo "ERROR: Backup verification failed — backup directory is empty"
  exit 1
fi

# Clean up backups older than 7 days
echo "[$(date +%H:%M:%S)] Cleaning up backups older than 7 days..."
find "$BACKUP_BASE" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;
echo "[$(date +%H:%M:%S)] Old backups cleaned"

echo "[$(date +%H:%M:%S)] Backup finished successfully"
```

### Schedule with Cron

Add to crontab for daily execution at 2:00 AM:

```cron
0 2 * * * /path/to/scripts/cassandra-backup.sh >> /var/log/cassandra-backup.log 2>&1
```

---

## Restore Script

Location: `scripts/cassandra-restore.sh`

```bash
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
SNAPSHOT_TAG="restore_$(date +%Y%m%d)"

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

# Verify container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: Cassandra container '$CONTAINER' is not running"
  exit 1
fi

# Create a pre-restore snapshot for safety
echo "[$(date +%H:%M:%S)] Creating pre-restore safety snapshot..."
docker exec "$CONTAINER" nodetool snapshot -t "$SNAPSHOT_TAG" "$KEYSPACE" || true

# Truncate existing tables (faster than full data dir removal)
echo "[$(date +%H:%M:%S)] Truncating existing tables..."
docker exec "$CONTAINER" cqlsh -e "TRUNCATE ${KEYSPACE}.url_mappings;"
docker exec "$CONTAINER" cqlsh -e "TRUNCATE ${KEYSPACE}.url_metadata;"

# Drop and recreate keyspace to ensure fresh schema
echo "[$(date +%H:%M:%S)] Dropping and recreating keyspace..."
docker exec -i "$CONTAINER" cqlsh < scripts/init-cassandra.cql

# Restore data from snapshot
echo "[$(date +%H:%M:%S)] Restoring data from backup..."
docker cp "$BACKUP_DIR/$KEYSPACE" "${CONTAINER}:/var/lib/cassandra/data/"

# Set correct ownership
echo "[$(date +%H:%M:%S)] Setting file permissions..."
docker exec "$CONTAINER" chown -R cassandra:cassandra "/var/lib/cassandra/data/$KEYSPACE"

# Trigger SSTable reload without restart
echo "[$(date +%H:%M:%S)] Loading new SSTables..."
TABLE_DIRS=$(docker exec "$CONTAINER" ls "/var/lib/cassandra/data/$KEYSPACE" 2>/dev/null || true)

for DIR in $TABLE_DIRS; do
  TABLE_NAME=$(echo "$DIR" | sed 's/-.*//')
  echo "  Loading SSTables for: $TABLE_NAME"
  docker exec "$CONTAINER" nodetool refresh "$KEYSPACE" "$TABLE_NAME" || true
done

# Run repair for consistency
echo "[$(date +%H:%M:%S)] Running repair..."
docker exec "$CONTAINER" nodetool repair "$KEYSPACE" || true

echo "[$(date +%H:%M:%S)] Verifying restore..."
docker exec "$CONTAINER" cqlsh -e "SELECT COUNT(*) FROM ${KEYSPACE}.url_mappings;"

echo "[$(date +%H:%M:%S)] Restore complete"
```

---

## Verification

### Verify Backup Integrity

```bash
# Check backup directory exists and has content
ls -la /backups/YYYYMMDD_HHMMSS/url_shortener/

# Check snapshot was cleared
docker exec cassandra nodetool listsnapshots
# Should show no snapshots for url_shortener (after clearsnapshot)
```

### Verify Restore

```bash
# Check row count
docker exec cassandra cqlsh -e "SELECT COUNT(*) FROM url_shortener.url_mappings;"

# Test a known short URL
docker exec cassandra cqlsh -e "SELECT * FROM url_shortener.url_mappings WHERE short_id = 'abc123';"

# Check cluster health
docker exec cassandra nodetool status
```

### Monitor Backup Logs

```bash
tail -f /var/log/cassandra-backup.log
```