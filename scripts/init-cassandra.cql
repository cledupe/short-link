CREATE KEYSPACE IF NOT EXISTS url_shortener
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};

CREATE TABLE IF NOT EXISTS url_shortener.url_mappings (
    short_id TEXT PRIMARY KEY,
    original_url TEXT,
    created_at TIMESTAMP,
    visit_count COUNTER
);

CREATE TABLE IF NOT EXISTS url_shortener.url_metadata (
    short_id TEXT,
    creator_ip TEXT,
    user_agent TEXT,
    created_at TIMESTAMP,
    PRIMARY KEY (short_id, created_at)
);