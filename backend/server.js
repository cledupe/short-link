const express = require('express');
const healthRouter = require('./src/routes/health');
const urlsRouter = require('./src/routes/urls');
const redirectRouter = require('./src/routes/redirect');
const { corsMiddleware, securityHeadersMiddleware } = require('./src/middleware/security');
const { metricsMiddleware, getMetrics } = require('./src/services/metrics');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(corsMiddleware);
app.use(securityHeadersMiddleware);
app.use(express.json({ limit: '1mb' }));
app.use(metricsMiddleware);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(await getMetrics());
});

app.use('/health', healthRouter);
app.use('/ready', healthRouter);
app.use('/api/v1/urls', urlsRouter);

app.use('/', redirectRouter);

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
  });
}

module.exports = app;