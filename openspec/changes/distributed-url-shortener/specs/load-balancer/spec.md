## ADDED Requirements

### Requirement: Traffic Distribution
The system SHALL distribute incoming HTTP requests across multiple application instances using a load balancer.

#### Scenario: Round-robin distribution
- **WHEN** multiple HTTP requests arrive at the load balancer
- **THEN** the load balancer SHALL distribute them in round-robin fashion across healthy application instances
- **AND** the distribution rate SHALL be approximately equal (within 10%) across all instances

#### Scenario: Health check integration
- **WHEN** an application instance becomes unhealthy (fails health checks)
- **THEN** the load balancer SHALL stop routing traffic to that instance
- **AND** within 30 seconds, NO new requests SHALL be sent to the unhealthy instance
- **AND** existing requests being processed SHALL complete normally

#### Scenario: Instance recovery
- **WHEN** a previously unhealthy instance recovers and passes health checks
- **THEN** the load balancer SHALL add it back to the active pool
- **AND** start routing traffic to the recovered instance
- **AND** distribution SHALL re-balance across all healthy instances

### Requirement: Health Check Endpoints
The system SHALL expose health check endpoints for load balancer monitoring.

#### Scenario: Application health endpoint
- **WHEN** a GET request is made to `/health`
- **THEN** the system SHALL return 200 OK if all critical components (Cassandra, Redis, encryption) are healthy
- **AND** the response SHALL include status details for each component
- **AND** the response time SHALL be under 500ms

#### Scenario: Load balancer health check
- **WHEN** the load balancer performs health checks on application instances
- **THEN** the system SHALL respond within 1 second
- **AND** healthy instances SHALL return HTTP 200
- **AND** unhealthy instances SHALL return HTTP 503 or timeout

#### Scenario: Readiness check
- **WHEN** a GET request is made to `/ready`
- **THEN** the system SHALL return 200 OK only if it's ready to accept traffic
- **AND** return 503 if still initializing or unable to serve requests

### Requirement: High Availability
The system SHALL maintain service availability during infrastructure failures.

#### Scenario: Single instance failure
- **WHEN** one application instance crashes or becomes unresponsive
- **THEN** the load balancer SHALL detect the failure within 30 seconds
- **AND** remaining instances SHALL handle all traffic without degradation
- **AND** the service SHALL maintain >99.9% availability

#### Scenario: Rolling deployment
- **WHEN** new versions are deployed via rolling updates
- **THEN** the load balancer SHALL gracefully shift traffic from old to new versions
- **AND** no requests SHALL be lost during the transition
- **AND** users SHALL experience no downtime

### Requirement: Session Persistence
The system SHALL maintain session persistence (sticky sessions) where required.

#### Scenario: Optional session affinity
- **WHEN** URL creation requests contain session identifiers (for rate limiting)
- **THEN** the load balancer MAY use IP hash to route subsequent requests from the same client to the same instance
- **AND** this SHALL help maintain rate limiting consistency

### Requirement: Load Balancer Performance
The system SHALL handle high traffic volumes efficiently.

#### Scenario: High throughput handling
- **WHEN** 10,000 requests per second are sent to the load balancer
- **THEN** the load balancer SHALL distribute all requests without dropping any
- **AND** p99 latency for request distribution SHALL be under 50ms
- **AND** no single instance SHALL receive more than 10% of total traffic

#### Scenario: Connection pooling
- **WHEN** the load balancer maintains connections to backend instances
- **THEN** it SHALL use connection pooling to reuse connections
- **AND** this SHALL reduce connection establishment overhead
- **AND** each connection SHALL be validated before reuse
