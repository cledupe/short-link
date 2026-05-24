# Monitoring & Observability

## Overview

The distributed URL shortener uses **Prometheus** for metrics collection and **Grafana** for dashboard visualization. This document describes the available metrics, dashboards, alert rules, and how to access the monitoring stack.

## Architecture

```
┌──────────────┐     scrape (/metrics)     ┌──────────────┐
│  Backend x3  │ ◄─────────────────────── │  Prometheus   │
│  (Node.js)   │     port 3000             │  :9090        │
└──────────────┘                           └──────┬───────┘
                                                  │ query
                                           ┌──────▼───────┐
                                           │   Grafana     │
                                           │   :3001       │
                                           └──────────────┘
```

## Access

| Service   | URL                     | Credentials     |
|-----------|-------------------------|-----------------|
| Prometheus| http://localhost:9090   | None (local)    |
| Grafana   | http://localhost:3001   | admin / admin   |

## Prometheus Metrics

All metrics are exposed at `GET /metrics` on the backend (port 3000).

### HTTP Metrics

| Metric                     | Type      | Labels                          | Description                     |
|----------------------------|-----------|---------------------------------|---------------------------------|
| `http_request_duration_ms` | Histogram | `method`, `route`, `status_code`| Request latency in ms           |
| `http_requests_total`      | Counter   | `method`, `route`, `status_code`| Total request count             |

Buckets: `[5, 10, 25, 50, 100, 250, 500, 1000]` ms

### Cache Metrics

| Metric               | Type    | Description              |
|----------------------|---------|--------------------------|
| `cache_hits_total`   | Counter | Total Redis cache hits   |
| `cache_misses_total` | Counter | Total Redis cache misses |

Calculate hit rate: `rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) * 100`

### Cassandra Metrics

| Metric                        | Type      | Labels        | Description                        |
|-------------------------------|-----------|---------------|------------------------------------|
| `cassandra_query_duration_ms` | Histogram | `query_type`  | Cassandra query latency in ms      |

Query types: `select_short_id`, `select_original_url`, `insert_url_mapping`, `insert_url_metadata`, `increment_visit_count`, `insert_visit_analytics`

### Default Metrics (auto-collected)

Prometheus `collectDefaultMetrics` also provides Node.js runtime metrics:
- `process_cpu_user_seconds_total`
- `process_resident_memory_bytes`
- `nodejs_eventloop_lag_seconds`
- `nodejs_heap_size_used_bytes`
- `nodejs_heap_size_total_bytes`

## Grafana Dashboards

### Setup

1. Open Grafana at http://localhost:3001
2. Login with `admin` / `admin` (change password on first login)
3. Add Prometheus data source: URL `http://prometheus:9090`
4. Import or create dashboards

### Recommended Dashboard Panels

| Panel                   | Metric Query                                               |
|-------------------------|-------------------------------------------------------------|
| Request Rate            | `rate(http_requests_total[1m])`                            |
| P95 Latency             | `histogram_quantile(0.95, rate(http_request_duration_ms_bucket[1m]))` |
| Error Rate              | `rate(http_requests_total{status_code=~"5.."}[1m]) / rate(http_requests_total[1m]) * 100` |
| Cache Hit Rate          | `rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) * 100` |
| Cassandra Latency       | `histogram_quantile(0.95, rate(cassandra_query_duration_ms_bucket[1m]))` |
| Memory Usage            | `nodejs_heap_size_used_bytes`                              |

## Alert Configuration

Alerts are defined in Prometheus recording rules and alerting rules. Below are the recommended alert thresholds.

### High Error Rate

```
alert: HighErrorRate
expr: rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100 > 1
for: 5m
labels: { severity: critical }
annotations: { summary: "Error rate above 1% for 5 minutes" }
```

### High Latency (P95 > 100ms)

```
alert: HighLatencyP95
expr: histogram_quantile(0.95, rate(http_request_duration_ms_bucket[5m])) > 100
for: 5m
labels: { severity: warning }
annotations: { summary: "P95 latency above 100ms" }
```

### Low Cache Hit Rate

```
alert: LowCacheHitRate
expr: rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) * 100 < 50
for: 5m
labels: { severity: warning }
annotations: { summary: "Cache hit rate below 50%" }
```

### Node Failures (Cassandra, Redis, Backend)

Monitor health endpoint (`/health`) for component status. In production, set up blackbox exporter probes:

```
alert: BackendDown
expr: up{job="backend"} == 0
for: 1m
labels: { severity: critical }
annotations: { summary: "Backend instance down" }
```

For Cassandra and Redis, monitor the `/health` endpoint response body for degraded component status.

### Disk Usage Alert

```
alert: DiskUsageHigh
expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100 > 80
for: 5m
labels: { severity: warning }
annotations: { summary: "Disk usage above 80%" }
```

*Note: Disk usage alerts require `node_exporter` to be deployed on each host.*

## Distributed Tracing

Distributed tracing via OpenTelemetry/Jaeger is **planned** for future implementation. Once added, traces will be available at `http://localhost:16686` (Jaeger UI).

## Log Aggregation

Log aggregation via ELK/Fluentd is **planned** for future implementation. Backend currently logs to stdout, which is captured by Docker's logging driver.

## Future Enhancements

- Add `node_exporter` for host-level metrics (CPU, memory, disk)
- Deploy Alertmanager for alert routing (email, Slack, PagerDuty)
- Set up OpenTelemetry SDK for distributed tracing
- Integrate Fluentd for structured log shipping to Elasticsearch
- Add Grafana Loki for log exploration