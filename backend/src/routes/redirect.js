const express = require('express');
const cache = require('../services/cache');
const { findUrlByShortId, incrementVisitCount, storeVisitAnalytics } = require('../services/cassandra');

const pendingFetches = new Map();

const router = express.Router();

router.get('/:shortId', async (req, res) => {
  const { shortId } = req.params;

  if (!/^[0-9a-zA-Z]{1,10}$/.test(shortId)) {
    return res.status(404).json({ error: 'URL not found' });
  }

  try {
    let originalUrl = await cache.get(shortId);

    if (!originalUrl) {
      if (pendingFetches.has(shortId)) {
        originalUrl = await pendingFetches.get(shortId);
      } else {
        const fetchPromise = findUrlByShortId(shortId);
        pendingFetches.set(shortId, fetchPromise);

        const mapping = await fetchPromise;
        pendingFetches.delete(shortId);

        if (!mapping) {
          return res.status(404).json({ error: 'URL not found' });
        }

        originalUrl = mapping.original_url;

        await cache.set(shortId, originalUrl, 86400).catch(err => {
          console.error(`Failed to cache ${shortId}:`, err.message);
        });
      }
    }

    incrementVisitCount(shortId).catch(err => {
      console.error(`Failed to increment visit count for ${shortId}:`, err.message);
    });
    storeVisitAnalytics(shortId, req.ip || req.connection.remoteAddress, req.headers['user-agent'] || 'unknown').catch(err => {
      console.error(`Failed to store visit analytics for ${shortId}:`, err.message);
    });

    res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');

    return res.redirect(302, originalUrl);
  } catch (err) {
    console.error(`Redirect error for ${shortId}:`, err.message);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;