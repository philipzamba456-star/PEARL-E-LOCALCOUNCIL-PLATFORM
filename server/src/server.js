require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');

const { initPool, closePool } = require('./db');
const authRoutes = require('./routes/auth');
const apiRoutes = require('./routes/api');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({ origin: process.env.CORS_ORIGIN || true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

app.use('/api/auth', authRoutes);
app.use('/api', apiRoutes);

app.get('/api/health', (req, res) => res.json({ ok: true, time: new Date().toISOString() }));

// Serve the frontend (public/) as static files
app.use(express.static(path.join(__dirname, '..', '..', 'public')));
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '..', '..', 'public', 'index.html'));
});

// Central error handler (last resort)
app.use((err, req, res, next) => {
  console.error('[unhandled]', err);
  res.status(500).json({ error: 'Unexpected server error.' });
});

async function start() {
  try {
    await initPool();
  } catch (e) {
    console.error('\n[FATAL] Could not connect to Oracle. Check your .env settings.');
    console.error(e.message);
    process.exit(1);
  }
  app.listen(PORT, () => {
    console.log(`\nPearls E-Local Council Platform running at http://localhost:${PORT}\n`);
  });
}

process.on('SIGINT', async () => { await closePool(); process.exit(0); });
process.on('SIGTERM', async () => { await closePool(); process.exit(0); });

start();
