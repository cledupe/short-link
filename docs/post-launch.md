# Post-Launch & Maintenance Guide

## 1. Post-Mortem Template

### Incident Post-Mortem Template

```
## Post-Mortem: [TITLE]

**Date:** YYYY-MM-DD
**Severity:** P0 (Critical) / P1 (High) / P2 (Medium) / P3 (Low)
**Duration:** [Start] → [End] ([total time])
**Reported by:** [Name]
**Affected components:** [e.g., Redis, Cassandra, Backend, Nginx]

### Summary
Brief description of what happened and impact on users.

### Timeline (UTC)
- HH:MM — First alert triggered
- HH:MM — Engineer acknowledged
- HH:MM — Root cause identified
- HH:MM — Mitigation applied
- HH:MM — Service fully recovered

### Root Cause
Detailed explanation of what caused the incident.

### Resolution Steps
1. Step one
2. Step two
3. Step three

### Impact
- Requests affected: [count]
- Error rate: [%]
- Latency p95: [ms]
- User-facing downtime: [duration]

### Action Items
| # | Action | Owner | Ticket | Priority |
|---|--------|-------|--------|----------|
| 1 | Add monitoring for [metric] | @name | LINK | P0 |
| 2 | Update runbook for [scenario] | @name | LINK | P1 |

### Lessons Learned
- What went well?
- What went wrong?
- What can be improved?

### Follow-up
- [ ] Create monitoring alert for [condition]
- [ ] Update deployment checklist
- [ ] Schedule post-mortem review meeting
```

## 2. Performance Review Cadence

### Regular Reviews

| Cadence | Focus | Participants |
|---------|-------|-------------|
| Daily | Error rates, latency spikes, cache hit rate | On-call engineer |
| Weekly | Throughput trends, capacity thresholds, slow queries | SRE team |
| Monthly | Full performance report, bottleneck analysis, cost review | Engineering team |
| Quarterly | Architecture review, scaling plan, technology upgrades | All stakeholders |

### Performance Metrics to Track

- **Throughput**: req/s (average, peak)
- **Latency**: p50, p95, p99 for `/api/v1/urls` POST and `GET /:shortId`
- **Cache**: hit rate, memory usage, eviction rate
- **Cassandra**: read/write latency, compaction backlog, disk usage
- **Redis**: memory fragmentation, connected clients, ops/s
- **Nginx**: active connections, upstream response times, 5xx rate

### Performance Review Process

1. Pull latest metrics from Grafana dashboards
2. Compare against baseline from performance testing (Section 12)
3. Identify regressions (>10% change in p95 latency or error rate)
4. Profile slow queries in Cassandra (`cqlsh` tracing)
5. Review Redis SLOWLOG for slow commands
6. Document findings in performance review log

## 3. Cache Optimization Guidelines

### TTL Tuning

| URL Type | Suggested TTL | Rationale |
|----------|---------------|-----------|
| High-traffic (>1000 hits/day) | 48-72 hours | Reduce Cassandra read load |
| Medium-traffic (100-1000 hits/day) | 24 hours | Balance freshness vs. load |
| Low-traffic (<100 hits/day) | 6-12 hours | Free cache space for hot URLs |
| Expired/deleted URLs | Immediate eviction | Prevent serving stale URLs |

### Eviction Policies

- **Current**: LRU (Least Recently Used) — default for Redis
- **Alternative**: LFU (Least Frequently Used) — if cache pollution is observed
- **Switch to LFU**: `redis-cli CONFIG SET maxmemory-policy allkeys-lfu`

### Cache Warming

When a new backend instance starts:
```bash
# Identify top 1000 most-accessed URLs from Cassandra
SELECT short_id FROM url_mappings ORDER BY visit_count DESC LIMIT 1000;
# Preload into Redis
redis-cli -h redis-cluster SET <short_id> <original_url> EX 86400
```

### Monitoring Cache Effectiveness

- **Target hit rate**: >80% (warning at <70%, critical at <50%)
- **Memory limit**: 75% of maxmemory (trigger scale-up at 80%)
- **Eviction rate**: >1% of total keys per hour indicates undersized cache

## 4. Cassandra Compaction Tuning

### Current Strategy

LeveledCompactionStrategy (LCS) — optimal for read-heavy workloads with frequent reads.

### Tuning Parameters

```sql
-- Check current compaction settings
SELECT table_name, compaction FROM system_schema.tables
WHERE keyspace_name = 'url_shortener';

-- Adjust compaction for high write volume
ALTER TABLE url_mappings WITH compaction = {
  'class': 'LeveledCompactionStrategy',
  'sstable_size_in_mb': 160,
  'level_compaction_threads': 4,
  'max_threshold': 32,
  'min_threshold': 4
};
```

### Compaction Recommendations

| Write Volume | Strategy | SSTable Size | Threads |
|-------------|----------|--------------|---------|
| Low (<1k writes/s) | LCS | 80 MB | 2 |
| Medium (1k-10k writes/s) | LCS | 160 MB | 4 |
| High (>10k writes/s) | STCS | 320 MB | 8 |

### Compaction Monitoring

```bash
# Check compaction backlog
nodetool compactionstats

# Check pending compactions
nodetool cfstats url_shortener

# Force major compaction (off-peak only)
nodetool compact url_shortener url_mappings
```

### Best Practices

- Schedule major compaction during low-traffic windows (e.g., 3:00 AM)
- Monitor disk space before and after compaction (can require 50% free space)
- Disable compaction temporarily during bulk imports (re-enable afterward)
- Set `gc_grace_seconds` to 86400 (10 days) for deletes

## 5. Security Review Process

### Daily Review

- [ ] Check Nginx error logs for anomalous request patterns
- [ ] Review rate-limit hit counts per IP
- [ ] Monitor WAF alert dashboard
- [ ] Verify all services are responding to health checks

### Weekly Review

- [ ] Review security incident log (last 7 days)
- [ ] Check for known CVEs in dependencies (`npm audit`)
- [ ] Rotate API tokens if any were exposed
- [ ] Review IP blacklist additions

### Monthly Review

- [ ] Full security audit of Nginx and WAF rules
- [ ] Penetration test (or automated security scan)
- [ ] Review access logs for suspicious activity
- [ ] Update SSL/TLS certificate expiry calendar

### WAF Rule Adjustments

```nginx
# Example: Block requests with suspicious query parameters
if ($args ~* "(<script|%3Cscript|SELECT.*FROM|DROP|UNION)") {
    return 403;
}

# Example: Rate-limit by URL pattern
location /api/v1/urls/batch {
    limit_req zone=batch burst=5 nodelay;
    limit_conn batch_conn 2;
    proxy_pass http://backend;
}
```

### Incident Response

1. **Detect**: Alert triggers (error rate >1%, p95 latency >500ms)
2. **Triage**: Determine severity and affected components
3. **Mitigate**: Apply emergency measures (rate-limit, block IP, restart service)
4. **Resolve**: Fix root cause, deploy fix
5. **Post-mortem**: Document incident within 48 hours

## 6. Capacity Planning

### Growth Tracking

| Metric | Current | 30-day Trend | 90-day Projection |
|--------|---------|-------------|-------------------|
| Total URLs created | [value] | [trend] | [projected] |
| Daily new URLs | [value] | [trend] | [projected] |
| Daily redirects | [value] | [trend] | [projected] |
| Active short IDs | [value] | [trend] | [projected] |

### Scaling Triggers

| Component | Scale-Up When | Action |
|-----------|--------------|--------|
| Backend (Node.js) | CPU >70% sustained for 10 min | Add instance (docker-compose up --scale backend=N+1) |
| Cassandra | Disk >75% or read latency >50ms | Add node or increase disk size |
| Redis | Memory >75% of maxmemory | Increase maxmemory or add replica |
| Nginx | Active connections >90% of worker_connections | Tune worker_connections or add LB instance |

### Capacity Planning Process

1. **Weekly**: Check growth rate of URLs and redirects
2. **Monthly**: Compare actual growth against projections
3. **Quarterly**: Full capacity review with budget planning
4. **Threshold check**: Automated alerts when any trigger is hit

### Node Sizing Reference

| Component | Minimum | Recommended | High-Volume |
|-----------|---------|-------------|-------------|
| Backend | 1 vCPU, 1 GB RAM | 2 vCPU, 2 GB RAM | 4 vCPU, 4 GB RAM |
| Cassandra | 2 vCPU, 4 GB RAM, 50 GB SSD | 4 vCPU, 8 GB RAM, 100 GB SSD | 8 vCPU, 16 GB RAM, 500 GB SSD |
| Redis | 1 vCPU, 2 GB RAM | 2 vCPU, 4 GB RAM | 4 vCPU, 16 GB RAM |
| Nginx | 1 vCPU, 512 MB RAM | 2 vCPU, 1 GB RAM | 4 vCPU, 2 GB RAM |

## 7. Lessons Learned Documentation

### Template

```
## Lessons Learned — [Date/Phase]

### What Went Well
1. [Achievement]
2. [Achievement]

### What Could Be Improved
1. [Area for improvement]
2. [Area for improvement]

### Key Takeaways
- [Takeaway 1]
- [Takeaway 2]

### Process Changes
- [Change 1] — [Ticket/PR link]
- [Change 2] — [Ticket/PR link]

### Team Feedback
- [Feedback point]
- [Feedback point]
```

### Lessons Learned Log

| Date | Phase | Key Lesson | Action Taken |
|------|-------|------------|-------------|
| [Date] | Launch | [Lesson] | [Action] |
| [Date] | Week 1 | [Lesson] | [Action] |

### Retrospective Cadence

- **Post-launch**: Retrospective within 1 week of full production rollout
- **Monthly**: Lightweight retrospective with key metrics review
- **Quarterly**: Full retrospective with all team members
- **Post-incident**: Retrospective within 48 hours of any P0/P1 incident

## 8. Next Phase Feature Ideas

### Short-Term (Next 3 Months)

| Priority | Feature | Rationale | Effort |
|----------|---------|-----------|--------|
| P1 | Custom short URLs (vanity slugs) | User demand for branded links | Medium |
| P1 | URL expiration (TTL per link) | Auto-cleanup of unused links | Small |
| P2 | QR code generation | Common use case for short links | Small |
| P2 | Basic analytics dashboard | Show click counts per URL over time | Medium |
| P2 | API key authentication | Enable programmatic access for partners | Medium |

### Medium-Term (3-6 Months)

| Priority | Feature | Rationale | Effort |
|----------|---------|-----------|--------|
| P1 | Rate-limited tiers (free/pro) | Monetization path | Large |
| P2 | Bulk CSV import/export | Enterprise onboarding | Medium |
| P2 | Geo-redirect (country-based routing) | Marketing campaigns | Large |
| P3 | UTM parameter builder | Marketing integrations | Small |
| P3 | Webhook notifications on URL visits | Real-time event streaming | Medium |

### Long-Term (6-12 Months)

| Priority | Feature | Rationale | Effort |
|----------|---------|-----------|--------|
| P1 | Multi-tenant support with orgs | Enterprise readiness | Large |
| P1 | Custom domains (branded short domain) | Premium offering | Large |
| P2 | Click fraud detection | Analytics integrity | Medium |
| P2 | A/B testing for redirect destinations | Marketing optimization | Medium |
| P3 | Public API with SDKs | Ecosystem growth | Large |

### Infrastructure Improvements

| Item | Rationale | Priority |
|------|-----------|----------|
| Kubernetes migration | Auto-scaling + self-healing | P2 |
| Multi-region deployment | Lower latency for global users | P2 |
| Read replicas for Cassandra | Scale read throughput | P2 |
| CDN integration for redirects | Edge caching for faster redirects | P3 |
| gRPC for inter-service communication | Lower latency between services | P3 |