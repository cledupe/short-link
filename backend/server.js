const express = require('express');
const healthRouter = require('./src/routes/health');
const urlsRouter = require('./src/routes/urls');
const redirectRouter = require('./src/routes/redirect');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json({ limit: '1mb' }));

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - start}ms`);
  });
  next();
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