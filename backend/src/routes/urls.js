const express = require('express');
const { getNextId, reserveIds } = require('../services/counter');
const base62 = require('base62');
const cassandra = require('../services/cassandra');
const cache = require('../services/cache');
const { createRateLimiter, sanitizeUrl } = require('../middleware/security');

const router = express.Router();

const RATE_LIMIT_WINDOW = 60 * 1000;
const RATE_LIMIT_MAX = 100;
const BATCH_MAX_URLS = 100;

const rateLimiter = createRateLimiter(RATE_LIMIT_MAX, RATE_LIMIT_WINDOW);

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
    cache.set(existing.short_id, existing.original_url).catch(err => {
      console.error(`[URLS] Failed to cache duplicate ${existing.short_id}:`, err.message);
    });
    return { shortId: existing.short_id, originalUrl: existing.original_url, isDuplicate: true };
  }

  const id = await getNextId();
  const shortId = encode(id);

  await cassandra.insertUrlMapping(shortId, originalUrl);
  await cassandra.insertUrlMetadata(shortId, ip, userAgent);
  cache.set(shortId, originalUrl).catch(err => {
    console.error(`[URLS] Failed to cache ${shortId}:`, err.message);
  });

  return { shortId, originalUrl, isDuplicate: false };
}

router.post('/', rateLimiter, async (req, res) => {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';

  const { original_url } = req.body;
  const sanitized = sanitizeUrl(original_url);
  if (!sanitized) {
    return res.status(400).json({ error: 'Invalid URL. Must start with http:// or https:// and be a valid URL.' });
  }

  try {
    const result = await createShortUrl(sanitized, ip, req.headers['user-agent'] || 'unknown');
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

router.post('/batch', rateLimiter, async (req, res) => {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';

  const { urls } = req.body;
  if (!Array.isArray(urls) || urls.length === 0) {
    return res.status(400).json({ error: 'urls must be a non-empty array.' });
  }
  if (urls.length > BATCH_MAX_URLS) {
    return res.status(400).json({ error: `Maximum ${BATCH_MAX_URLS} URLs per batch request.` });
  }

  const validUrls = urls.map(u => sanitizeUrl(u)).filter(Boolean);
  if (validUrls.length === 0) {
    return res.status(400).json({ error: 'No valid URLs provided.' });
  }

  try {
    const results = [];
    const newUrls = [];

    for (const url of validUrls) {
      const existing = await cassandra.findUrlByOriginalUrl(url);
      if (existing) {
        cache.set(existing.short_id, existing.original_url).catch(err => {
          console.error(`[URLS] Failed to cache duplicate ${existing.short_id}:`, err.message);
        });
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
        cache.set(shortId, url).catch(err => {
          console.error(`[URLS] Failed to cache batch ${shortId}:`, err.message);
        });

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

router.delete('/:shortId', async (req, res) => {
  const { shortId } = req.params;
  if (!shortId || !/^[0-9a-zA-Z]{1,10}$/.test(shortId)) {
    return res.status(400).json({ error: 'Invalid shortId.' });
  }

  try {
    const mapping = await cassandra.findUrlByShortId(shortId);
    if (!mapping) {
      return res.status(404).json({ error: 'Short URL not found.' });
    }

    await cache.del(shortId);
    console.log(`[URLS] Cache invalidated for ${shortId}`);

    return res.status(200).json({ short_id: shortId, message: 'Cache invalidated successfully.' });
  } catch (err) {
    console.error(`[URLS] Error invalidating cache for ${shortId}:`, err.message);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;