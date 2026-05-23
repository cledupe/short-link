# Cassandra CQL Query Reference

Complete CQL reference for the `url_shortener` keyspace, including schema definitions, common queries, and operational patterns.

---

## Table of Contents

- [Schema Overview](#schema-overview)
- [Keyspace Definition](#keyspace-definition)
- [Tables](#tables)
  - [url_mappings](#url_mappings)
  - [url_metadata](#url_metadata)
- [INSERT Examples](#insert-examples)
- [SELECT Examples](#select-examples)
- [UPDATE Examples](#update-examples)
- [DELETE Examples](#delete-examples)
- [BATCH Operations](#batch-operations)
- [Table Operations](#table-operations)
- [Time-Range Queries](#time-range-queries)
- [Aggregation Queries](#aggregation-queries)
- [Schema Management](#schema-management)

---

## Schema Overview

```
url_shortener keyspace (RF=3, SimpleStrategy)
├── url_mappings   — stores short_id → original_url mapping + visit counter
└── url_metadata   — stores per-request metadata (creator IP, user agent)
```

---

## Keyspace Definition

```cql
CREATE KEYSPACE IF NOT EXISTS url_shortener
WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 3
};
```

### Switch to Keyspace

```cql
USE url_shortener;
```

---

## Tables

### url_mappings

Primary mapping table. Counter column tracks total visits.

```cql
CREATE TABLE IF NOT EXISTS url_shortener.url_mappings (
    short_id TEXT PRIMARY KEY,
    original_url TEXT,
    created_at TIMESTAMP,
    visit_count COUNTER
) WITH compaction = { 'class': 'LeveledCompactionStrategy' }
  AND gc_grace_seconds = 86400;
```

| Column        | Type        | Description                          |
|---------------|-------------|--------------------------------------|
| `short_id`    | TEXT        | Base62-encoded unique identifier (PK) |
| `original_url`| TEXT        | Original long URL (plaintext)         |
| `created_at`  | TIMESTAMP   | Row creation timestamp                |
| `visit_count` | COUNTER     | Incremented on each redirect          |

**Compaction:** LeveledCompactionStrategy — optimizes for read-heavy workloads.
**gc_grace_seconds:** 86400 (24 hours) — time before tombstoned data is purged.

### url_metadata

Clustering table for per-redirect metadata, ordered by creation time.

```cql
CREATE TABLE IF NOT EXISTS url_shortener.url_metadata (
    short_id TEXT,
    creator_ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMP,
    PRIMARY KEY (short_id, created_at)
);
```

| Column       | Type        | Description                          |
|--------------|-------------|--------------------------------------|
| `short_id`   | TEXT        | References url_mappings.short_id      |
| `creator_ip` | TEXT        | IP address of the creator             |
| `user_agent` | TEXT        | User-Agent header from creator        |
| `created_at` | TIMESTAMP   | Partition+clustering key              |

**Primary key:** `(short_id, created_at)` — partitions by short_id, clusters by time.

---

## INSERT Examples

### Insert a New URL Mapping

```cql
INSERT INTO url_mappings (short_id, original_url, created_at)
VALUES ('abc123', 'https://example.com/very-long-url', toTimestamp(now()));
```

### Insert with Metadata

```cql
INSERT INTO url_mappings (short_id, original_url, created_at)
VALUES ('xyz789', 'https://docs.example.com/api/reference/v2', toTimestamp(now()));

INSERT INTO url_metadata (short_id, creator_ip, user_agent, created_at)
VALUES (
  'xyz789',
  '192.168.1.100',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
  toTimestamp(now())
);
```

### Insert with Specific Timestamp

```cql
INSERT INTO url_mappings (short_id, original_url, created_at)
VALUES ('abc123', 'https://example.com/page', '2025-01-15T10:30:00Z');
```

---

## SELECT Examples

### Lookup by Short ID (Primary Key)

```cql
-- Single row lookup (most common query)
SELECT * FROM url_mappings WHERE short_id = 'abc123';
```

### Select Specific Columns

```cql
SELECT original_url, visit_count FROM url_mappings WHERE short_id = 'abc123';
```

### List All URLs Created on a Given Date

```cql
SELECT short_id, original_url, created_at
FROM url_metadata
WHERE short_id = 'abc123'
ORDER BY created_at DESC;
```

### Get Latest Metadata Entries

```cql
-- Most recent 10 metadata entries for a URL
SELECT * FROM url_metadata
WHERE short_id = 'abc123'
ORDER BY created_at DESC
LIMIT 10;
```

### Check If a Short ID Exists

```cql
SELECT COUNT(*) FROM url_mappings WHERE short_id = 'abc123';
```

---

## UPDATE Examples

### Increment Visit Counter

```cql
-- Atomic counter increment on each redirect
UPDATE url_mappings SET visit_count = visit_count + 1 WHERE short_id = 'abc123';
```

> **Note:** Counter columns cannot be mixed with non-counter columns in the same UPDATE statement. If you need to update `original_url` and increment `visit_count` atomically, use a BATCH.

### Update Original URL

```cql
-- Only possible if visit_count is not a counter (use with caution)
-- Counter columns cannot be updated with SET; they only support increment/decrement
```

---

## DELETE Examples

### Delete a URL Mapping

```cql
DELETE FROM url_mappings WHERE short_id = 'abc123';
```

### Delete Associated Metadata

```cql
DELETE FROM url_metadata WHERE short_id = 'abc123';
```

### Delete Metadata by Time Range

```cql
DELETE FROM url_metadata
WHERE short_id = 'abc123'
  AND created_at >= '2025-01-01T00:00:00Z'
  AND created_at < '2025-01-02T00:00:00Z';
```

---

## BATCH Operations

### Atomic Write: Insert Mapping + Metadata

```cql
BEGIN BATCH
  INSERT INTO url_mappings (short_id, original_url, created_at)
  VALUES ('abc123', 'https://example.com/page', toTimestamp(now()));

  INSERT INTO url_metadata (short_id, creator_ip, user_agent, created_at)
  VALUES ('abc123', '192.168.1.1', 'curl/7.88.1', toTimestamp(now()));
APPLY BATCH;
```

### Atomic Counter Increment with Metadata Log

```cql
BEGIN BATCH
  UPDATE url_mappings SET visit_count = visit_count + 1 WHERE short_id = 'abc123';

  INSERT INTO url_metadata (short_id, creator_ip, user_agent, created_at)
  VALUES ('abc123', '10.0.0.55', 'Mozilla/5.0', toTimestamp(now()));
APPLY BATCH;
```

> **Note:** BATCH with counter updates and regular inserts is supported but incurs a performance penalty. Use BATCH for atomicity, not as a general-purpose write optimization.

### Conditional Batch (Lightweight Transaction)

```cql
BEGIN BATCH
  INSERT INTO url_mappings (short_id, original_url, created_at)
  VALUES ('new123', 'https://example.com/new-page', toTimestamp(now()))
  IF NOT EXISTS;

  INSERT INTO url_metadata (short_id, creator_ip, user_agent, created_at)
  VALUES ('new123', '10.0.0.1', 'Chrome/120', toTimestamp(now()));
APPLY BATCH;
```

---

## Table Operations

### Truncate Table (Remove All Rows)

```cql
TRUNCATE url_mappings;
TRUNCATE url_metadata;
```

### Drop Table

```cql
DROP TABLE IF EXISTS url_mappings;
DROP TABLE IF EXISTS url_metadata;
```

### Describe Table Schema

```cql
DESCRIBE TABLE url_mappings;
DESCRIBE TABLE url_metadata;
```

---

## Time-Range Queries

### Query Metadata Between Two Dates

Because `url_metadata` uses `(short_id, created_at)` as the primary key, you can efficiently query time ranges within a partition:

```cql
-- All metadata entries for abc123 on January 15, 2025
SELECT * FROM url_metadata
WHERE short_id = 'abc123'
  AND created_at >= '2025-01-15T00:00:00Z'
  AND created_at < '2025-01-16T00:00:00Z';
```

### Get Entries from Last 24 Hours

```cql
SELECT * FROM url_metadata
WHERE short_id = 'abc123'
  AND created_at >= toTimestamp(now()) - 86400000;
```

### Get Most Recent Entry

```cql
SELECT * FROM url_metadata
WHERE short_id = 'abc123'
ORDER BY created_at DESC
LIMIT 1;
```

---

## Aggregation Queries

### Count Total Mappings

```cql
SELECT COUNT(*) FROM url_mappings;
```

### Get Total Visit Count

```cql
SELECT visit_count FROM url_mappings WHERE short_id = 'abc123';
```

### Count Metadata Entries for a Short ID

```cql
SELECT COUNT(*) FROM url_metadata WHERE short_id = 'abc123';
```

---

## Schema Management

### Add a Column

```cql
ALTER TABLE url_mappings ADD expires_at TIMESTAMP;
```

### Drop a Column

```cql
ALTER TABLE url_mappings DROP expires_at;
```

### Change Table Properties

```cql
ALTER TABLE url_mappings
WITH compaction = { 'class': 'SizeTieredCompactionStrategy' };
```

### Update Keyspace Replication

```cql
ALTER KEYSPACE url_shortener
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'dc1': 3,
  'dc2': 2
};
```