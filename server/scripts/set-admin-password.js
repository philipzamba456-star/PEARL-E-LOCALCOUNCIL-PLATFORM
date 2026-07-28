/**
 * Usage:
 *   node scripts/set-admin-password.js <username> <newPassword>
 *
 * Example:
 *   node scripts/set-admin-password.js admin MyStrongPass123
 *
 * This is how you set the very first login password after running the
 * SQL scripts (Phase 5, 6, 9, 11) — the seed data creates the 'admin'
 * app_user row but, correctly, never puts a password in SQL source.
 */
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { withConnection, closePool } = require('../src/db');

async function main() {
  const [, , username, password] = process.argv;
  if (!username || !password || password.length < 6) {
    console.error('Usage: node scripts/set-admin-password.js <username> <newPassword (min 6 chars)>');
    process.exit(1);
  }

  const hash = await bcrypt.hash(password, 10);

  await withConnection(async (conn) => {
    const result = await conn.execute(
      `UPDATE app_user SET password_hash = :hash WHERE UPPER(username) = UPPER(:username)`,
      { hash, username },
      { autoCommit: true }
    );
    if (result.rowsAffected === 0) {
      console.error(`No app_user found with username '${username}'. Create one first (see README).`);
      process.exit(1);
    }
    console.log(`Password set for '${username}'. You can now log in with it.`);
  });

  await closePool();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
