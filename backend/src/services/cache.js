const { getClient } = require('./redis');

const metrics = { hits: 0, misses: 0, startTime: Date.now() };

async function get(shortId) {
  const redis = getClient();
  const url = await redis.get(shortId);
  if (url) metrics.hits++;
  else metrics.misses++;
  return url;
}

async function set(shortId, originalUrl, ttl = 86400) {
  const redis = getClient();
  await redis.setex(shortId, ttl, originalUrl);
}

async function del(shortId) {
  const redis = getClient();
  await redis.del(shortId);
}

function getMetrics() {
  const total = metrics.hits + metrics.misses;
  return {
    hits: metrics.hits,
    misses: metrics.misses,
    total,
    hitRate: total ? (metrics.hits / total * 100).toFixed(2) + '%' : '0%',
    uptime: Math.floor((Date.now() - metrics.startTime) / 1000)
  };
}

function resetMetrics() {
  metrics.hits = 0;
  metrics.misses = 0;
  metrics.startTime = Date.now();
}

module.exports = { get, set, del, getMetrics, resetMetrics };