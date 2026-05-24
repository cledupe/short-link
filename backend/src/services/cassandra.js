const cassandra = require('cassandra-driver');
const { observeCassandraQuery } = require('./metrics');

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
  const start = Date.now();
  const result = await getClient().execute(
    'SELECT * FROM url_mappings WHERE short_id = ?',
    [shortId],
    { prepare: true }
  );
  observeCassandraQuery('select_short_id', Date.now() - start);
  return result.first() || null;
}

async function findUrlByOriginalUrl(originalUrl) {
  const start = Date.now();
  const result = await getClient().execute(
    'SELECT * FROM url_mappings WHERE original_url = ? ALLOW FILTERING',
    [originalUrl],
    { prepare: true }
  );
  observeCassandraQuery('select_original_url', Date.now() - start);
  return result.first() || null;
}

async function insertUrlMapping(shortId, originalUrl) {
  const start = Date.now();
  await getClient().execute(
    'INSERT INTO url_mappings (short_id, original_url, created_at, visit_count) VALUES (?, ?, ?, 0)',
    [shortId, originalUrl, new Date()],
    { prepare: true }
  );
  observeCassandraQuery('insert_url_mapping', Date.now() - start);
}

async function insertUrlMetadata(shortId, ip, userAgent) {
  const start = Date.now();
  await getClient().execute(
    'INSERT INTO url_metadata (short_id, creator_ip, user_agent, created_at) VALUES (?, ?, ?, ?)',
    [shortId, ip, userAgent, new Date()],
    { prepare: true }
  );
  observeCassandraQuery('insert_url_metadata', Date.now() - start);
}

async function incrementVisitCount(shortId) {
  const start = Date.now();
  await getClient().execute(
    'UPDATE url_mappings SET visit_count = visit_count + 1 WHERE short_id = ?',
    [shortId],
    { prepare: true }
  );
  observeCassandraQuery('increment_visit_count', Date.now() - start);
}

async function storeVisitAnalytics(shortId, ip, userAgent) {
  const start = Date.now();
  await getClient().execute(
    'INSERT INTO visit_analytics (short_id, visited_at, visitor_ip, user_agent) VALUES (?, ?, ?, ?)',
    [shortId, new Date(), ip, userAgent],
    { prepare: true }
  );
  observeCassandraQuery('insert_visit_analytics', Date.now() - start);
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
  storeVisitAnalytics,
  isReady,
  shutdown
};