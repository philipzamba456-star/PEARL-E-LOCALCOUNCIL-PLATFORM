/**
 * Loads one or more .sql files into the database pointed at by
 * DATABASE_URL (or PGHOST/PGPORT/etc for local dev). No psql install
 * needed — this uses the same 'pg' package the app already depends on.
 *
 * Usage:
 *   DATABASE_URL="postgresql://..." node scripts/run-sql.js sql-postgres/01_Schema.sql sql-postgres/02_Seed_Data.sql
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { withConnection, closePool } = require('../src/db');

async function main() {
  const files = process.argv.slice(2);
  if (files.length === 0) {
    console.error('Usage: node scripts/run-sql.js <file1.sql> [file2.sql ...]');
    process.exit(1);
  }

  for (const file of files) {
    const fullPath = path.resolve(process.cwd(), file);
    if (!fs.existsSync(fullPath)) {
      console.error(`File not found: ${fullPath}`);
      process.exit(1);
    }
    const sql = fs.readFileSync(fullPath, 'utf8');
    console.log(`\n--- Running ${file} ---`);
    try {
      await withConnection((client) => client.query(sql));
      console.log(`✓ ${file} completed successfully.`);
    } catch (e) {
      console.error(`✗ ${file} FAILED: ${e.message}`);
      process.exit(1);
    }
  }

  console.log('\nAll files completed successfully.');
  await closePool();
}

main().catch((e) => { console.error(e); process.exit(1); });
