const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { withConnection } = require('./db');

const SCHEMA_FILE = path.join(__dirname, '..', 'sql-postgres', '01_Schema.sql');
const SEED_FILE = path.join(__dirname, '..', 'sql-postgres', '02_Seed_Data.sql');
const DEFAULT_ADMIN_PASSWORD = process.env.DEFAULT_ADMIN_PASSWORD || 'ChangeMe123!';

/**
 * Runs once per boot. If the schema hasn't been loaded yet (no 'parish'
 * table found), it self-initializes: creates all tables, loads the demo
 * seed data, and sets a working password on the seeded 'admin' account —
 * so a brand new empty database (like a fresh Render/Railway Postgres)
 * becomes a fully working, loggable-into app with zero manual SQL steps.
 *
 * Safe to call on every startup: it checks first and does nothing if the
 * schema already exists, so redeploys/restarts never re-run this.
 */
async function autoMigrate() {
  await withConnection(async (client) => {
    const check = await client.query(
      `SELECT EXISTS (
         SELECT 1 FROM information_schema.tables
         WHERE table_schema = 'public' AND table_name = 'parish'
       ) AS exists`
    );

    if (check.rows[0].exists) {
      console.log('[migrate] Schema already present — skipping auto-setup.');
      return;
    }

    console.log('[migrate] Empty database detected — running first-time setup...');

    const schemaSql = fs.readFileSync(SCHEMA_FILE, 'utf8');
    await client.query(schemaSql);
    console.log('[migrate] Schema created (38 tables).');

    const seedSql = fs.readFileSync(SEED_FILE, 'utf8');
    await client.query(seedSql);
    console.log('[migrate] Demo seed data loaded.');

    const hash = await bcrypt.hash(DEFAULT_ADMIN_PASSWORD, 10);
    await client.query(`UPDATE app_user SET password_hash = $1 WHERE username = 'admin'`, [hash]);
    console.log(`[migrate] Demo login ready -> username: admin / password: ${DEFAULT_ADMIN_PASSWORD}`);
    console.log('[migrate] Change this password after logging in (Administration -> User Accounts is a start,');
    console.log('[migrate] though a full change-password UI is a good next addition).');
  });
}

module.exports = { autoMigrate };
