const { Pool } = require('pg');

let pool;

/**
 * Initialise the connection pool. Railway's PostgreSQL add-on injects a
 * single DATABASE_URL — that's all that's needed there. For local dev
 * without a DATABASE_URL, falls back to individual PG* variables.
 */
async function initPool() {
  if (pool) return pool;

  const connectionString = process.env.DATABASE_URL;

  pool = connectionString
    ? new Pool({
        connectionString,
        ssl: process.env.PGSSL === 'false' ? false : { rejectUnauthorized: false },
        max: Number(process.env.PG_POOL_MAX || 10),
      })
    : new Pool({
        host: process.env.PGHOST || 'localhost',
        port: Number(process.env.PGPORT || 5432),
        database: process.env.PGDATABASE,
        user: process.env.PGUSER,
        password: process.env.PGPASSWORD,
        max: Number(process.env.PG_POOL_MAX || 10),
      });

  // Fail fast if credentials are wrong, rather than only failing on first query.
  const client = await pool.connect();
  client.release();

  console.log(`[db] PostgreSQL pool created${connectionString ? ' (via DATABASE_URL)' : ''}`);
  return pool;
}

/** Run fn(client) inside a pooled connection, always releasing it. */
async function withConnection(fn) {
  const p = await initPool();
  const client = await p.connect();
  try {
    return await fn(client);
  } finally {
    client.release();
  }
}

/** Convenience: run one parameterised query, return the pg result object. */
async function execute(sql, params = []) {
  const p = await initPool();
  return p.query(sql, params);
}

async function closePool() {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}

module.exports = { initPool, withConnection, execute, closePool };
