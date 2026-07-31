require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');

const { initPool, closePool } = require('./db');
const { autoMigrate } = require('./migrate');
const authRoutes = require('./routes/auth');
const apiRoutes = require('./routes/api');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({ origin: process.env.CORS_ORIGIN || true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

app.get('/api/health', async (req, res) => {
  try {
    const { execute } = require('./db');
    await execute('SELECT 1');
    res.json({ ok: true, database: 'connected', time: new Date().toISOString() });
  } catch (e) {
    res.status(503).json({
      ok: false,
      database: 'NOT CONNECTED',
      error: e.message,
      code: e.code || null,
      hint: 'Check DATABASE_URL in your host\'s Environment/Variables settings.',
      time: new Date().toISOString(),
    });
  }
});

app.use('/api/auth', authRoutes);
app.use('/api', apiRoutes);

// Serve the frontend (public/) as static files
app.use(express.static(path.join(__dirname, '..', 'public')));
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

// Central error handler (last resort)
app.use((err, req, res, next) => {
  console.error('[unhandled]', err);
  res.status(500).json({ error: 'Unexpected server error.' });
});

async function start() {
  // IMPORTANT: bind the port immediately, regardless of DB connectivity.
  // A platform like Render/Railway health-checks the port — if we crash
  // the whole process because the DB isn't reachable *yet* (wrong env var,
  // DB still starting up, etc.), the platform restart-loops the container,
  // which both hides the real error and makes the app impossible to debug
  // from outside. Instead: start the HTTP server unconditionally, and let
  // each API route's own error handling (which already logs and returns
  // the real database error) surface the problem clearly and repeatably.
  app.listen(PORT, () => {
    console.log(`\nPearls E-Local Council Platform running at http://localhost:${PORT}\n`);
  });

  try {
    await initPool();
    console.log('[db] Startup connectivity check: OK');
    await autoMigrate();
  } catch (e) {
    console.error('\n[WARNING] Could not connect to PostgreSQL at startup.');
    console.error('DATABASE_URL is set:', Boolean(process.env.DATABASE_URL));
    console.error('Error code:', e.code || '(none)');
    console.error('Error message:', e.message);
    console.error('The server will keep running — every API call will report this same error');
    console.error('until DATABASE_URL / DB credentials are fixed. No restart needed once fixed;');
    console.error('the pool retries on the next request automatically.\n');
  }
}

process.on('SIGINT', async () => { await closePool(); process.exit(0); });
process.on('SIGTERM', async () => { await closePool(); process.exit(0); });

start();
