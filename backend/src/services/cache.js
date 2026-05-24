const { getClient } = require('./redis');
const { observeCacheHit, observeCacheMiss } = require('./metrics');

async function get(shortId) {
  const redis = getClient();
  const start = Date.now();
  const url = await redis.get(shortId);
  if (url) observeCacheHit();
  else observeCacheMiss();
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

module.exports = { get, set, del };