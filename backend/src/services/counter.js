const { getClient } = require('./redis');

const COUNTER_KEY = 'url:counter';
const MAX_RETRIES = 3;

const ALERT_THRESHOLDS = [0.50, 0.75, 0.90];
let alertedThresholds = new Set();

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function withRetry(fn, context) {
  let lastError;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const redis = getClient();
      return await fn(redis);
    } catch (err) {
      lastError = err;
      console.error(`[Counter] ${context} attempt ${attempt}/${MAX_RETRIES} failed:`, err.message);
      if (attempt < MAX_RETRIES) {
        await sleep(Math.pow(2, attempt) * 100);
      }
    }
  }
  console.error(`[Counter] ${context} exhausted after ${MAX_RETRIES} retries`);
  throw new Error(`Failed to ${context} after ${MAX_RETRIES} retries`);
}

async function checkThreshold(value) {
  const currentStr = await withRetry(async (redis) => {
    return await redis.get(COUNTER_KEY);
  }, 'get current value for threshold check');

  if (!currentStr) return;

  const current = parseInt(currentStr, 10);
  if (current === 0) return;

  for (const threshold of ALERT_THRESHOLDS) {
    if (value >= current * threshold && !alertedThresholds.has(threshold)) {
      alertedThresholds.add(threshold);
      console.log(`[Counter Monitor] WARNING: Counter at ${Math.round(threshold * 100)}% of current value (${value}/${current})`);
    }
  }
}

async function getNextId() {
  return withRetry(async (redis) => {
    const id = await redis.incr(COUNTER_KEY);
    console.log(`[Counter] INCR ${COUNTER_KEY} => ${id}`);
    await checkThreshold(id).catch(err => console.error('[Counter] Threshold check error:', err.message));
    return id;
  }, 'increment counter');
}

async function reserveIds(count) {
  return withRetry(async (redis) => {
    const startId = await redis.incrby(COUNTER_KEY, count);
    const reservedStart = startId - count + 1;
    console.log(`[Counter] INCRBY ${COUNTER_KEY} ${count} => reserved [${reservedStart}-${startId}]`);
    return { start: reservedStart, end: startId };
  }, `reserve ${count} IDs`);
}

async function getCurrentValue() {
  return withRetry(async (redis) => {
    const val = await redis.get(COUNTER_KEY);
    const num = val ? parseInt(val, 10) : 0;
    console.log(`[Counter] GET ${COUNTER_KEY} => ${num}`);
    return num;
  }, 'get current value');
}

function getCounterKey() {
  return COUNTER_KEY;
}

function resetAlertedThresholds() {
  alertedThresholds = new Set();
}

module.exports = {
  getNextId,
  reserveIds,
  getCurrentValue,
  getCounterKey,
  resetAlertedThresholds,
  COUNTER_KEY
};