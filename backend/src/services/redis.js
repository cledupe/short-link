const Redis = require('ioredis');

let client = null;

function createClient() {
  const url = process.env.REDIS_URL || 'redis://redis:6379';
  const instance = new Redis(url, {
    maxRetriesPerRequest: 3,
    enableReadyCheck: true,
    lazyConnect: true,
    connectionName: 'url-shortener',
  });

  instance.on('connect', () => {
    console.log('[Redis] Connected successfully');
  });

  instance.on('error', (err) => {
    console.error('[Redis] Connection error:', err.message);
  });

  instance.on('close', () => {
    console.warn('[Redis] Connection closed');
  });

  instance.on('reconnecting', (delay) => {
    console.log(`[Redis] Reconnecting in ${delay}ms`);
  });

  return instance;
}

function getClient() {
  if (!client) {
    client = createClient();
  }
  return client;
}

function closeClient() {
  if (client) {
    client.disconnect();
    client = null;
  }
}

module.exports = { getClient, closeClient };