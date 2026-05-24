# Redis Key Naming Conventions

## Keys

| Key Pattern | Type | Purpose | TTL |
|-------------|------|---------|-----|
| `url:counter` | String | Atomic counter for short ID generation | None (persistent) |
| `{shortId}` | String | Cache mapping shortId to original_url | 24 hours (86400s) |

## Examples

```
url:counter = 42
abc123 = "https://example.com/very/long/url"
```

## Memory Configuration
- Max memory: 256MB
- Eviction policy: allkeys-lru
- Persistence: AOF with everysec fsync