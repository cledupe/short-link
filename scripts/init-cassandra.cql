CREATE KEYSPACE IF NOT EXISTS url_shortener
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};