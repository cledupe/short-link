## ADDED Requirements

### Requirement: Short URL Generation
The system SHALL accept original URLs and return unique, short URLs with base62-encoded identifiers.

#### Scenario: Create new short URL successfully
- **WHEN** a POST request is made to `/api/v1/urls` with a valid original URL in the request body
- **THEN** the system SHALL generate a unique base62-encoded identifier using the distributed counter
- **AND** encrypt the original URL for secure storage
- **AND** store the mapping in Cassandra with replication across 3 nodes
- **AND** return a JSON response with the short URL within 100ms
- **AND** the HTTP status code SHALL be 201 Created

#### Scenario: URL validation
- **WHEN** a POST request is made with an invalid or malformed URL
- **THEN** the system SHALL reject the request
- **AND** return a 400 Bad Request response with error details

#### Scenario: Handle duplicate URL submissions
- **WHEN** a POST request is made with a URL that already exists in the system
- **THEN** the system SHALL return the existing short URL mapping
- **AND** the HTTP status code SHALL be 200 OK
- **AND** no new database entry SHALL be created

#### Scenario: Rate limiting protection
- **WHEN** more than 100 URL creation requests are received from the same client within 1 minute
- **THEN** the system SHALL reject subsequent requests
- **AND** return a 429 Too Many Requests response

### Requirement: Batch URL Creation
The system SHALL support creating multiple short URLs in a single request.

#### Scenario: Batch creation
- **WHEN** a POST request is made to `/api/v1/urls/batch` with an array of up to 100 URLs
- **THEN** the system SHALL generate unique short URLs for each valid URL
- **AND** return a JSON array containing all mappings with corresponding short URLs
- **AND** the HTTP status code SHALL be 201 Created
- **AND** any invalid URLs SHALL be rejected with detailed error messages

### Requirement: URL Metadata Storage
The system SHALL store metadata for each short URL mapping.

#### Scenario: Metadata creation
- **WHEN** a short URL is created
- **THEN** the system SHALL store: creation timestamp, creator IP, user agent, and original URL hash
- **AND** store this metadata in Cassandra alongside the URL mapping
