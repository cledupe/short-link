CREATE KEYSPACE IF NOT EXISTS url_shortener
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};

CREATE TABLE IF NOT EXISTS url_shortener.url_mappings (
    short_id TEXT PRIMARY KEY,
    original_url TEXT,
    created_at TIMESTAMP,
    visit_count COUNTER
) WITH compaction = { 'class': 'LeveledCompactionStrategy' }
  AND gc_grace_seconds = 86400;

CREATE TABLE IF NOT EXISTS url_shortener.url_metadata (
    short_id TEXT,
    creator_ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMP,
    PRIMARY KEY (short_id, created_at)
);

CREATE INDEX IF NOT EXISTS idx_url_mappings_created_at
ON url_shortener.url_mappings (created_at);

CREATE INDEX IF NOT EXISTS idx_url_metadata_created_at
ON url_shortener.url_metadata (created_at);