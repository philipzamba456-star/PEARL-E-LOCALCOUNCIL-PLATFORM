const oracledb = require('oracledb');

oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;
oracledb.autoCommit = false;
oracledb.fetchAsString = [oracledb.CLOB];

let pool;

/**
 * Initialise the connection pool. Uses node-oracledb's THIN driver by
 * default (pure JavaScript — no Oracle Instant Client install required).
 * If you ever need THICK mode (e.g. for some older Oracle features),
 * call oracledb.initOracleClient() before this runs — see README.
 */
async function initPool() {
  if (pool) return pool;

  const connectString =
    process.env.ORACLE_CONNECT_STRING ||
    `${process.env.ORACLE_HOST}:${process.env.ORACLE_PORT || 1521}/${process.env.ORACLE_SERVICE_NAME}`;

  pool = await oracledb.createPool({
    user: process.env.ORACLE_USER,
    password: process.env.ORACLE_PASSWORD,
    connectString,
    poolMin: Number(process.env.ORACLE_POOL_MIN || 1),
    poolMax: Number(process.env.ORACLE_POOL_MAX || 10),
    poolIncrement: 1,
  });

  console.log(`[db] Oracle pool created -> ${connectString}`);
  return pool;
}

/** Run fn(connection) inside a pooled connection, always releasing it. */
async function withConnection(fn) {
  const p = await initPool();
  const conn = await p.getConnection();
  try {
    return await fn(conn);
  } finally {
    try { await conn.close(); } catch (e) { console.error('[db] close error', e); }
  }
}

/** Convenience: run one statement, commit, return result. */
async function execute(sql, binds = {}, opts = {}) {
  return withConnection(async (conn) => {
    const result = await conn.execute(sql, binds, { autoCommit: true, ...opts });
    return result;
  });
}

async function closePool() {
  if (pool) {
    await pool.close(0);
    pool = undefined;
  }
}

module.exports = { initPool, withConnection, execute, closePool, oracledb };
