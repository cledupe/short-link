const express = require('express');
const { getNextId, reserveIds } = require('../services/counter');
const { encode } = require('../utils/base62');
const cassandra = require('../services/cassandra');

const router = express.Router();

const RATE_LIMIT_WINDOW = 60 * 1000;
const RATE_LIMIT_MAX = 100;
const BATCH_MAX_URLS = 100;

const rateLimitMap = new Map();

function getRateLimitInfo(ip) {
  const now = Date.now();
  const record = rateLimitMap.get(ip);
  if (!record || now - record.windowStart > RATE_LIMIT_WINDOW) {
    const info = { windowStart: now, count: 0 };
    rateLimitMap.set(ip, info);
    return info;
  }
  return record;
}

function checkRateLimit(ip) {
  const info = getRateLimitInfo(ip);
  info.count++;
  return info.count <= RATE_LIMIT_MAX;
}

setInterval(() => {
  const now = Date.now();
  for (const [ip, record] of rateLimitMap.entries()) {
    if (now - record.windowStart > RATE_LIMIT_WINDOW) {
      rateLimitMap.delete(ip);
    }
  }
}, 60 * 1000);

const URL_REGEX = /^https?:\/\/.+/i;

function isValidUrl(str) {
  if (!str || typeof str !== 'string') return false;
  str = str.trim();
  if (!URL_REGEX.test(str)) return false;
  try {
    new URL(str);
    return true;
  } catch {
    return false;
  }
}

async function createShortUrl(originalUrl, ip, userAgent) {
  const existing = await cassandra.findUrlByOriginalUrl(originalUrl);
  if (existing) {
    return { shortId: existing.short_id, originalUrl: existing.original_url, isDuplicate: true };
  }

  const id = await getNextId();
  const shortId = encode(id);

  await cassandra.insertUrlMapping(shortId, originalUrl);
  await cassandra.insertUrlMetadata(shortId, ip, userAgent);

  return { shortId, originalUrl, isDuplicate: false };
}

router.post('/', async (req, res) => {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';
  if (!checkRateLimit(ip)) {
    return res.status(429).json({ error: 'Rate limit exceeded. Try again later.' });
  }

  const { original_url } = req.body;
  if (!isValidUrl(original_url)) {
    return res.status(400).json({ error: 'Invalid URL. Must start with http:// or https:// and be a valid URL.' });
  }

  try {
    const result = await createShortUrl(original_url.trim(), ip, req.headers['user-agent'] || 'unknown');
    const shortUrl = `${req.protocol}://${req.get('host')}/${result.shortId}`;

    if (result.isDuplicate) {
      return res.status(200).json({
        short_url: shortUrl,
        short_id: result.shortId,
        original_url: result.originalUrl,
        duplicate: true
      });
    }

    return res.status(201).json({
      short_url: shortUrl,
      short_id: result.shortId,
      original_url: result.originalUrl
    });
  } catch (err) {
    console.error('[URLS] Error creating short URL:', err.message);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/batch', async (req, res) => {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';
  if (!checkRateLimit(ip)) {
    return res.status(429).json({ error: 'Rate limit exceeded. Try again later.' });
  }

  const { urls } = req.body;
  if (!Array.isArray(urls) || urls.length === 0) {
    return res.status(400).json({ error: 'urls must be a non-empty array.' });
  }
  if (urls.length > BATCH_MAX_URLS) {
    return res.status(400).json({ error: `Maximum ${BATCH_MAX_URLS} URLs per batch request.` });
  }

  const validUrls = urls.map(u => (typeof u === 'string' ? u.trim() : '')).filter(isValidUrl);
  if (validUrls.length === 0) {
    return res.status(400).json({ error: 'No valid URLs provided.' });
  }

  try {
    const results = [];
    const newUrls = [];

    for (const url of validUrls) {
      const existing = await cassandra.findUrlByOriginalUrl(url);
      if (existing) {
        results.push({
          original_url: url,
          short_url: `${req.protocol}://${req.get('host')}/${existing.short_id}`,
          short_id: existing.short_id,
          duplicate: true
        });
      } else {
        newUrls.push(url);
      }
    }

    if (newUrls.length > 0) {
      const { start } = await reserveIds(newUrls.length);
      const userAgent = req.headers['user-agent'] || 'unknown';

      for (let i = 0; i < newUrls.length; i++) {
        const shortId = encode(start + i);
        const url = newUrls[i];

        await cassandra.insertUrlMapping(shortId, url);
        await cassandra.insertUrlMetadata(shortId, ip, userAgent);

        results.push({
          original_url: url,
          short_url: `${req.protocol}://${req.get('host')}/${shortId}`,
          short_id: shortId
        });
      }
    }

    return res.status(201).json({ results, total: results.length });
  } catch (err) {
    console.error('[URLS] Batch creation error:', err.message);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:shortId', async (req, res) => {
  const { shortId } = req.params;
  if (!shortId || shortId.length === 0) {
    return res.status(400).json({ error: 'shortId is required.' });
  }

  try {
    const mapping = await cassandra.findUrlByShortId(shortId);
    if (!mapping) {
      return res.status(404).json({ error: 'Short URL not found.' });
    }
    return res.status(200).json({
      short_id: mapping.short_id,
      original_url: mapping.original_url,
      created_at: mapping.created_at,
      visit_count: mapping.visit_count
    });
  } catch (err) {
    console.error('[URLS] Error fetching URL:', err.message);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;