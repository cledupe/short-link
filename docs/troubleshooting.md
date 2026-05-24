# Troubleshooting Guide

## Common Issues and Solutions

### Backend fails to start

```
Error: Connection refused to cassandra:9042
```

**Solution:** Cassandra may still be bootstrapping. Wait 30-60s for first-time startup. Check status:

```bash
docker exec cassandra nodetool status
```

### Short URL returns 404

**Solution:** Check if the short ID exists in both Redis and Cassandra:

```bash
# Check Redis cache
docker exec redis redis-cli GET <shortId>

# Check Cassandra
docker exec cassandra cqlsh -e "SELECT * FROM url_shortener.url_mappings WHERE short_id = '<shortId>';"
```

### Rate limit errors (429)

**Solution:** Wait 60 seconds before retrying. Check current rate limit status in nginx logs:

```bash
docker-compose logs nginx | grep "limiting"
```

### 502 Bad Gateway from nginx

**Solution:** Backend instances may be down. Check and restart:

```bash
docker-compose ps backend
docker-compose restart backend
```

## How to Check Logs

### All services
```bash
docker-compose logs -f
```

### Specific service
```bash
docker-compose logs -f backend
docker-compose logs -f nginx
docker-compose logs -f cassandra
docker-compose logs -f redis
```

### Last 100 lines with timestamps
```bash
docker-compose logs --tail=100 -t backend
```

## How to Verify Connectivity Between Services

### Backend to Cassandra
```bash
docker exec backend ping cassandra -c 2
docker exec backend node -e "const c=require('cassandra-driver');new c.Client({contactPoints:['cassandra']}).connect().then(()=>console.log('OK'))"
```

### Backend to Redis
```bash
docker exec backend ping redis -c 2
docker exec redis redis-cli ping
```

### Nginx to Backend
```bash
docker exec nginx wget -qO- http://backend:3000/health
```

## How to Reset the Counter

```bash
docker exec redis redis-cli SET url:counter 0
```

**Warning:** Resetting the counter will cause new short IDs to collide with previously generated IDs if any exist. Only reset after a full data wipe.

## How to Clear the Cache

```bash
# Flush all Redis data (cache + counter)
docker exec redis redis-cli FLUSHALL

# Or remove only cached URL entries (keep counter)
docker exec redis redis-cli EVAL "return redis.call('del', unpack(redis.call('keys', redis.call('keys', '*'):filter(function(k) return k ~= 'url:counter' end))))" 0
```

## How to Rebuild Containers

```bash
# Rebuild and restart all services
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Rebuild a single service
docker-compose build --no-cache backend
docker-compose up -d backend
```