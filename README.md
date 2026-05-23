# Distributed URL Shortener

A high-performance, distributed URL shortening service built with Docker, Cassandra, Redis, and Vue.js.

## Architecture

```
┌─────────────┐
│   Nginx     │ (Load Balancer - Port 8080)
│   (LB)      │
└──────┬──────┘
       │
       ├──► Backend (Node.js) x3 (Ports 3000-3002)
       │      │
       │      ├──► Cassandra Cluster (3 nodes)
       │      └──► Redis Cluster (Cache + Counter)
       │
       └──► Frontend (Vue.js SPA)
```

## Project Structure

```
.
├── docker-compose.yml      # Docker Compose configuration for all services
├── Dockerfile              # Backend application Dockerfile
├── nginx.conf              # Nginx load balancer configuration
├── .env                    # Environment variables (not in git)
├── .env.example            # Environment variables template
├── .dockerignore           # Docker build exclusions
├── README.md               # This file
│
├── backend/                # Backend Node.js application
│   ├── package.json        # Dependencies
│   ├── server.js           # Main application entry point
│   └── ...                 # Application source files
│
├── frontend/               # Vue.js frontend application
│   ├── index.html          # Main HTML file
│   ├── App.vue             # Vue component
│   └── ...                 # Frontend source files
│
└── openspec/               # OpenSpec change tracking
    └── changes/
        └── distributed-url-shortener/
            ├── proposal.md
            ├── design.md
            ├── specs/
            └── tasks.md
```

## Services

| Service     | Description                          | Port(s)           |
|-------------|--------------------------------------|-------------------|
| nginx       | Load balancer for API and frontend   | 8080 (host:80)    |
| backend     | Node.js API server (scale: 3)        | 3000 (container)  |
| cassandra   | NoSQL database cluster (scale: 3)    | Internal only     |
| redis       | Cache and atomic counter (cluster)   | Internal only     |
| frontend    | Vue.js single-page application       | Served by nginx   |

## Quick Start

### Prerequisites

- Docker
- Docker Compose

### Running the Application

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Scale backend to 3 instances
docker-compose up --scale backend=3

# Stop all services
docker-compose down
```

### Environment Variables

Create a `.env` file in the project root:

```env
ENCRYPTION_KEY=your-32-character-encryption-key-here
```

## API Endpoints

- `POST /api/v1/urls` - Create a new short URL
- `GET /:shortId` - Redirect to original URL
- `GET /health` - Health check endpoint

## License

MIT
