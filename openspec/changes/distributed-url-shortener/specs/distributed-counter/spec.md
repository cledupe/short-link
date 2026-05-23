## ADDED Requirements

### Requirement: Atomic Counter Generation
The system SHALL use Redis atomic INCR operations to generate unique, monotonically increasing IDs across all application instances.

#### Scenario: Counter increments atomically
- **WHEN** multiple application instances simultaneously request the next available counter value
- **THEN** Redis SHALL return unique, sequential values to each instance
- **AND** no collisions SHALL occur under any concurrent load
- **AND** the counter value SHALL increment by exactly 1 for each request

#### Scenario: Counter persistence
- **WHEN** the system is restarted or Redis experiences a failure
- **THEN** the counter SHALL resume from its last committed value after recovery
- **AND** no duplicate or skipped values SHALL be generated

#### Scenario: Pre-allocation of IDs
- **WHEN** a batch request for multiple IDs is made
- **THEN** the system SHALL use INCRBY to atomically reserve a range of IDs
- **AND** return the starting value of the reserved range
- **AND** ensure no other instance can generate IDs within that range

### Requirement: Counter Key Management
The system SHALL maintain separate counters for different ID types or namespaces.

#### Scenario: URL ID counter
- **WHEN** the system needs a new URL identifier
- **THEN** it SHALL increment the `url:counter` key in Redis
- **AND** the returned value SHALL be used as the basis for base62 encoding

#### Scenario: Analytics event counter
- **WHEN** tracking events like page visits or API calls
- **THEN** the system SHALL increment separate counters like `analytics:visit:counter`
- **AND** these counters SHALL not interfere with URL ID generation

### Requirement: Base62 Conversion
The system SHALL convert numeric counter values to base62-encoded strings.

#### Scenario: Numeric to base62 conversion
- **WHEN** a numeric counter value (e.g., 1000000) is obtained from Redis
- **THEN** the system SHALL encode it to base62 using characters [0-9a-zA-Z]
- **AND** the resulting string SHALL be suitable for use in URLs
- **AND** the encoding SHALL be deterministic (same input yields same output)

#### Scenario: Collision resistance
- **WHEN** encoding sequential counter values (1, 2, 3...)
- **THEN** the resulting base62 strings SHALL be unique for each input
- **AND** the encoding SHALL produce compact strings (shorter than numeric representations)

### Requirement: Counter Performance
The system SHALL maintain high performance under load.

#### Scenario: High throughput counter operations
- **WHEN** 10,000 counter increment requests are made concurrently
- **THEN** Redis SHALL handle all requests with <5ms latency p95
- **AND** no request SHALL timeout or fail
- **AND** all IDs generated SHALL be unique
