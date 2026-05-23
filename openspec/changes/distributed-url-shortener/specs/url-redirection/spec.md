## ADDED Requirements

### Requirement: Short URL Resolution
The system SHALL resolve short URLs to their original destinations via HTTP redirects.

#### Scenario: Cache hit - Redis contains mapping
- **WHEN** a GET request is made to `/:shortId` where the mapping exists in Redis cache
- **THEN** the system SHALL return a 302 redirect to the original URL within 5ms

#### Scenario: Cache miss - Lookup in Cassandra
- **WHEN** a GET request is made to `/:shortId` where the mapping does NOT exist in Redis cache but exists in Cassandra
- **THEN** the system SHALL retrieve the mapping from Cassandra, cache it in Redis, and return a 302 redirect within 50ms
- **AND** subsequent requests for the same shortId SHALL use the Redis cache

#### Scenario: Short URL not found
- **WHEN** a GET request is made to `/:shortId` where the mapping does NOT exist in Cassandra
- **THEN** the system SHALL return a 404 Not Found response

#### Scenario: Track visit metrics
- **WHEN** a short URL is successfully resolved (302 redirect returned)
- **THEN** the system SHALL increment a visit counter for analytics
- **AND** store the timestamp of the visit in Cassandra for later analysis

### Requirement: Cache Invalidation
The system SHALL maintain cache consistency between Redis and Cassandra.

#### Scenario: Cache expiration
- **WHEN** a cached mapping reaches its TTL (24 hours)
- **THEN** Redis SHALL automatically expire the entry
- **AND** the next request SHALL load fresh data from Cassandra

### Requirement: Decryption on retrieval
The system SHALL decrypt stored URLs before performing redirects.

#### Scenario: Encrypted URL retrieval
- **WHEN** a short URL mapping is retrieved from storage
- **THEN** the system SHALL decrypt the original URL before performing the redirect
- **AND** the decryption process SHALL complete within 2ms

### Requirement: Concurrent request handling
The system SHALL handle concurrent requests for the same short URL.

#### Scenario: Multiple simultaneous requests
- **WHEN** 1000 concurrent requests arrive for the same shortId
- **THEN** the system SHALL process all requests successfully
- **AND** return consistent redirect responses to all clients
- **AND** maintain accurate visit counts
