const express = require('express');
const { default: Redis } = require('ioredis');
const cassandra = require('cassandra-driver');

const router = express.Router();

async function checkRedis(timeout) {
  const url = process.env.REDIS_URL;
  if (!url) {
    return { status: 'ok', detail: 'not configured (graceful degradation)' };
  }
  try {
    const redis = new Redis(url, {
      lazyConnect: true,
      connectTimeout: timeout,
      retryStrategy: () => null,
      maxRetriesPerRequest: 0,
    });
    await redis.connect();
    await redis.ping();
    await redis.disconnect();
    return { status: 'ok' };
  } catch (err) {
    return { status: 'error', detail: err.message };
  }
}

async function checkCassandra(timeout) {
  const nodes = (process.env.CASSANDRA_NODES || '127.0.0.1').split(',');
  try {
    const client = new cassandra.Client({
      contactPoints: nodes,
      localDataCenter: 'datacenter1',
      protocolOptions: { port: 9042 },
      socketOptions: { connectTimeout: timeout, readTimeout: timeout },
      policies: { retry: new cassandra.policies.retry.NoRetryPolicy() },
    });
    await client.connect();
    await client.execute('SELECT release_version FROM system.local');
    await client.shutdown();
    return { status: 'ok' };
  } catch (err) {
    return { status: 'error', detail: err.message };
  }
}

router.get('/health', async (req, res) => {
  const TIMEOUT = 500;
  const [redisResult, cassandraResult] = await Promise.all([
    checkRedis(TIMEOUT),
    checkCassandra(TIMEOUT),
  ]);
  const allOk = redisResult.status === 'ok' && cassandraResult.status === 'ok';
  res.status(allOk ? 200 : 503).json({
    status: allOk ? 'ok' : 'degraded',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    components: {
      redis: redisResult.status,
      cassandra: cassandraResult.status,
    },
  });
});

router.get('/ready', (req, res) => {
  res.status(200).json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

router.get('/metrics/cache', (req, res) => {
  const cache = require('../services/cache');
  res.status(200).json(cache.getMetrics());
});

module.exports = router;