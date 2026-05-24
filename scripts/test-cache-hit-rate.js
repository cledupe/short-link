#!/usr/bin/env node

const http = require('http');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8080';
const CREATIONS = parseInt(process.env.CREATIONS, 10) || 50;
const READS_PER = parseInt(process.env.READS_PER, 10) || 20;

const created = [];

function postUrl(url) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ original_url: url });
    const req = http.request(`${BASE_URL}/api/v1/urls`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) },
    }, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function getShortUrl(shortId) {
  return new Promise((resolve) => {
    const req = http.get(`${BASE_URL}/${shortId}`, { headers: { 'User-Agent': 'cache-test' } }, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => resolve({ status: res.statusCode, location: res.headers.location }));
    });
    req.on('error', () => resolve(null));
    req.end();
  });
}

function getMetrics() {
  return new Promise((resolve, reject) => {
    const req = http.get(`${BASE_URL}/health/metrics/cache`, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  console.log(`=== Cache Hit Rate Test ===`);
  console.log(`Creating ${CREATIONS} URLs, reading each ${READS_PER} times\n`);

  for (let i = 0; i < CREATIONS; i++) {
    const url = `https://example.com/cache-test/${Date.now()}-${i}`;
    try {
      const result = await postUrl(url);
      created.push(result.short_id);
      process.stdout.write(`\rCreated ${i + 1}/${CREATIONS}`);
    } catch (err) {
      console.error(`\nFailed to create URL ${i}: ${err.message}`);
    }
  }

  console.log(`\n\nReading each URL ${READS_PER} times (${created.length * READS_PER} total reads)...`);

  let readsDone = 0;
  for (const shortId of created) {
    for (let r = 0; r < READS_PER; r++) {
      await getShortUrl(shortId);
      readsDone++;
      if (readsDone % 50 === 0) {
        process.stdout.write(`\rReads: ${readsDone}/${created.length * READS_PER}`);
      }
    }
  }

  console.log(`\n\nFetching cache metrics...`);
  const metrics = await getMetrics();
  console.log(JSON.stringify(metrics, null, 2));

  const rate = parseFloat(metrics.hitRate);
  if (rate >= 90) {
    console.log(`\n✓ PASS: Hit rate ${metrics.hitRate} exceeds 90% target`);
  } else if (rate >= 80) {
    console.log(`\n✓ PASS: Hit rate ${metrics.hitRate} meets 80% minimum`);
  } else {
    console.log(`\n✗ FAIL: Hit rate ${metrics.hitRate} is below 80% target`);
  }
}

run().catch(console.error);