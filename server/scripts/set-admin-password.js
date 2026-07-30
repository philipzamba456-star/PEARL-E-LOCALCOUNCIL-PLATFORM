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

  await withConnection(async (client) => {
    const result = await client.query(
      `UPDATE app_user SET password_hash = $1 WHERE UPPER(username) = UPPER($2)`,
      [hash, username]
    );
    if (result.rowCount === 0) {
      console.error(`No app_user found with username '${username}'. Create one first (see README).`);
      process.exit(1);
    }
    console.log(`Password set for '${username}'. You can now log in with it.`);
  });

  await closePool();
}

main().catch((e) => { console.error(e); process.exit(1); });
