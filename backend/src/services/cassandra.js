const cassandra = require('cassandra-driver');

let client = null;

function createClient() {
  const nodes = (process.env.CASSANDRA_NODES || 'cassandra').split(',');
  const instance = new cassandra.Client({
    contactPoints: nodes,
    localDataCenter: 'datacenter1',
    keyspace: 'url_shortener',
    pooling: {
      coreConnectionsPerHost: {
        [cassandra.types.distance.local]: 10
      }
    },
    socketOptions: {
      connectTimeout: 5000
    }
  });

  instance.on('connected', () => {
    console.log('[Cassandra] Connected successfully');
  });

  instance.on('error', (err) => {
    console.error('[Cassandra] Connection error:', err.message);
  });

  return instance;
}

function getClient() {
  if (!client) {
    client = createClient();
  }
  return client;
}

async function findUrlByShortId(shortId) {
  const result = await getClient().execute(
    'SELECT * FROM url_mappings WHERE short_id = ?',
    [shortId],
    { prepare: true }
  );
  return result.first() || null;
}

async function findUrlByOriginalUrl(originalUrl) {
  const result = await getClient().execute(
    'SELECT * FROM url_mappings WHERE original_url = ? ALLOW FILTERING',
    [originalUrl],
    { prepare: true }
  );
  return result.first() || null;
}

async function insertUrlMapping(shortId, originalUrl) {
  await getClient().execute(
    'INSERT INTO url_mappings (short_id, original_url, created_at, visit_count) VALUES (?, ?, ?, 0)',
    [shortId, originalUrl, new Date()],
    { prepare: true }
  );
}

async function insertUrlMetadata(shortId, ip, userAgent) {
  await getClient().execute(
    'INSERT INTO url_metadata (short_id, creator_ip, user_agent, created_at) VALUES (?, ?, ?, ?)',
    [shortId, ip, userAgent, new Date()],
    { prepare: true }
  );
}

async function incrementVisitCount(shortId) {
  await getClient().execute(
    'UPDATE url_mappings SET visit_count = visit_count + 1 WHERE short_id = ?',
    [shortId],
    { prepare: true }
  );
}

function isReady() {
  if (!client) return false;
  return true;
}

async function shutdown() {
  if (client) {
    await client.shutdown();
    client = null;
  }
}

module.exports = {
  getClient,
  findUrlByShortId,
  findUrlByOriginalUrl,
  insertUrlMapping,
  insertUrlMetadata,
  incrementVisitCount,
  isReady,
  shutdown
};