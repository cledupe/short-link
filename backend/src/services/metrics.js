const promClient = require('prom-client');

const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_ms',
  help: 'HTTP request duration in milliseconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [5, 10, 25, 50, 100, 250, 500, 1000],
  registers: [register]
});

const httpRequestCount = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const cacheHits = new promClient.Counter({
  name: 'cache_hits_total',
  help: 'Total number of cache hits',
  registers: [register]
});

const cacheMisses = new promClient.Counter({
  name: 'cache_misses_total',
  help: 'Total number of cache misses',
  registers: [register]
});

const cassandraQueryDuration = new promClient.Histogram({
  name: 'cassandra_query_duration_ms',
  help: 'Cassandra query duration in milliseconds',
  labelNames: ['query_type'],
  buckets: [5, 10, 25, 50, 100, 250, 500],
  registers: [register]
});

function observeHttpRequest(method, route, statusCode, durationMs) {
  httpRequestDuration.observe({ method, route, status_code: statusCode }, durationMs);
  httpRequestCount.inc({ method, route, status_code: statusCode });
}

function observeCacheHit() { cacheHits.inc(); }
function observeCacheMiss() { cacheMisses.inc(); }
function observeCassandraQuery(type, durationMs) {
  cassandraQueryDuration.observe({ query_type: type }, durationMs);
}

function getMetrics() {
  return register.metrics();
}

function metricsMiddleware(req, res, next) {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    const route = req.route ? req.route.path : req.path;
    observeHttpRequest(req.method, route, res.statusCode, duration);
  });
  next();
}

module.exports = {
  metricsMiddleware,
  observeCacheHit,
  observeCacheMiss,
  observeCassandraQuery,
  getMetrics,
  register
};