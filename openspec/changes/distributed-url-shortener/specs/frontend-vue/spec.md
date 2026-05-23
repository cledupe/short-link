## ADDED Requirements

### Requirement: Simple URL Input Interface
The system SHALL provide a simple Vue.js interface allowing users to input a long URL and retrieve a shortened version without authentication.

#### Scenario: Initial page load
- **WHEN** a user navigates to the frontend root URL ("/")
- **THEN** the system SHALL display a clean interface with:
  - A labeled input field: "Enter your long URL"
  - A "Shorten URL" button
  - A result section (initially empty)
  - No authentication requirements or login forms

#### Scenario: URL submission
- **WHEN** a user pastes a valid URL (https://example.com/very/long/url) into the input field
- **AND** clicks the "Shorten URL" button
- **THEN** the frontend SHALL make a POST request to `/api/v1/urls` with JSON body: `{ "originalUrl": "https://example.com/very/long/url" }`
- **AND** display a loading indicator while waiting for response

#### Scenario: Display shortened URL
- **WHEN** the backend responds with 201 Created and JSON: `{ "shortUrl": "https://short.link/abc123" }`
- **THEN** the frontend SHALL display:
  - The shortened URL as clickable link
  - A "Copy to clipboard" button
  - Optional "Shorten another URL" button to reset form
- **AND** the displayed short URL SHALL be selectable for manual copying

#### Scenario: Invalid URL feedback
- **WHEN** a user enters an invalid URL (e.g., "not-a-url", "ftp://unsupported", or empty string)
- **AND** clicks "Shorten URL"
- **THEN** the frontend SHALL validate the URL format client-side before sending
- **AND** display an error message: "Please enter a valid HTTP/HTTPS URL"
- **AND** NOT send request to backend for clearly invalid URLs

#### Scenario: Backend error handling
- **WHEN** the backend returns an error (400, 429, 500)
- **THEN** the frontend SHALL display a user-friendly error message
- **AND** NOT expose technical details (e.g., database errors)
- **AND** allow user to retry with the same or different URL

### Requirement: Vue.js Implementation (MVP)
The system SHALL implement the frontend using Vue.js via CDN (no build step) for simplicity during MVP phase.

#### Scenario: No build process required
- **WHEN** deploying the frontend
- **THEN** the system SHALL use Vue.js loaded via CDN: `<script src="https://cdn.jsdelivr.net/npm/vue@3/dist/vue.global.js">`
- **AND** not require npm, webpack, or any build tools
- **AND** not require package.json or node_modules

#### Scenario: Single Vue component
- **WHEN** the frontend loads
- **THEN** a single Vue component SHALL mount to a DOM element (e.g., `#app`)
- **AND** handle all functionality: input binding, API calls, result display
- **AND** be implemented in a single HTML file or inline in served page

#### Scenario: No Vue Router dependency
- **WHEN** deploying MVP frontend
- **THEN** the system SHALL NOT include Vue Router
- **AND** serve a single page at root path ("/")
- **AND** not implement multiple routes/pages (out of scope for MVP)

### Requirement: Responsive Design
The system SHALL provide a responsive interface that works on desktop and mobile devices.

#### Scenario: Mobile usability
- **WHEN** accessing the frontend on a mobile device (width < 768px)
- **THEN** the input field and buttons SHALL be sized appropriately for touch interaction
- **AND** the layout SHALL be single-column for easy thumb navigation
- **AND** the font size SHALL be legible without zooming

### Requirement: Cross-Origin Requests
The system SHALL allow the frontend to make API calls from the browser to the backend API.

#### Scenario: Handling CORS
- **WHEN** Vue.js frontend (served from nginx at port 80) makes POST to `/api/v1/urls`
- **THEN** the backend API SHALL respond with proper CORS headers
- **AND** allow origin from the frontend domain
- **AND** allow methods: GET, POST, OPTIONS
- **AND** allow headers: Content-Type

### Requirement: Result Persistence (Session Only)
The system SHALL NOT persist URLs or results beyond the browser session (no user accounts).

#### Scenario: Page reload
- **WHEN** a user refreshes the page after getting a shortened URL
- **THEN** the previously shortened URL SHALL disappear
- **AND** the form SHALL reset to initial empty state
- **AND** the user SHOULD manually save shortened URLs if needed