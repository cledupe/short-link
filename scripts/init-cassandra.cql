-- Dev: SimpleStrategy for single-node Docker
-- Production: switch to NetworkTopologyStrategy with per-DC RF
--   CREATE KEYSPACE url_shortener WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter1': 3};
CREATE KEYSPACE IF NOT EXISTS url_shortener
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};

CREATE TABLE IF NOT EXISTS url_shortener.url_mappings (
    short_id TEXT PRIMARY KEY,
    original_url TEXT,
    created_at TIMESTAMP
) WITH compaction = { 'class': 'LeveledCompactionStrategy' }
  AND gc_grace_seconds = 864000;

CREATE TABLE IF NOT EXISTS url_shortener.url_visit_counts (
    short_id TEXT PRIMARY KEY,
    visit_count COUNTER
);

CREATE TABLE IF NOT EXISTS url_shortener.url_metadata (
    short_id TEXT,
    creator_ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMP,
    PRIMARY KEY (short_id, created_at)
);

CREATE TABLE IF NOT EXISTS url_shortener.visit_analytics (
    short_id TEXT,
    visitor_ip TEXT,
    user_agent TEXT,
    visited_at TIMESTAMP,
    PRIMARY KEY (short_id, visited_at)
);

-- WARNING: Secondary indexes on high-cardinality columns (created_at) perform poorly
-- in production. Consider using a materialized view or separate query table instead.
CREATE INDEX IF NOT EXISTS idx_url_mappings_created_at
ON url_shortener.url_mappings (created_at);

CREATE INDEX IF NOT EXISTS idx_url_metadata_created_at
ON url_shortener.url_metadata (created_at);