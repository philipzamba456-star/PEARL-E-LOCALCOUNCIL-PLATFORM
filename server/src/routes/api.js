const express = require('express');
const { withConnection, oracledb } = require('../db');
const { requireAuth } = require('../auth');
const { MODULES, TABLES, ADMIN_ROLES } = require('../metadata');

const router = express.Router();
router.use(requireAuth);

function isAdmin(req) {
  return (req.user.roles || []).some((r) => ADMIN_ROLES.includes(r));
}

function getTableOr404(req, res) {
  const t = TABLES[req.params.table];
  if (!t) {
    res.status(404).json({ error: `Unknown feature/table '${req.params.table}'` });
    return null;
  }
  if (t.adminOnly && !isAdmin(req)) {
    res.status(403).json({ error: 'Administrator access required for this feature.' });
    return null;
  }
  return t;
}

// ------------------------------------------------------------ FEATURE MAP
router.get('/meta', (req, res) => {
  const admin = isAdmin(req);
  const tables = Object.values(TABLES)
    .filter((t) => !t.adminOnly || admin)
    .map((t) => ({
      table: t.table, label: t.label, module: t.module,
      pk: t.pk, readOnly: t.readOnly, columns: t.columns,
    }));
  res.json({ modules: MODULES, tables });
});

// -------------------------------------------------------------- DASHBOARD
router.get('/dashboard', async (req, res) => {
  try {
    await withConnection(async (conn) => {
      const [residents, households, cases, reports, letters, announcements, payments] = await Promise.all([
        conn.execute(`SELECT COUNT(*) AS c FROM resident WHERE status = 'ACTIVE'`),
        conn.execute(`SELECT COUNT(*) AS c FROM household`),
        conn.execute(`SELECT case_status AS k, COUNT(*) AS c FROM court_case GROUP BY case_status`),
        conn.execute(`SELECT report_status AS k, COUNT(*) AS c FROM infrastructure_report GROUP BY report_status`),
        conn.execute(`SELECT request_status AS k, COUNT(*) AS c FROM letter_request GROUP BY request_status`),
        conn.execute(`SELECT COUNT(*) AS c FROM announcement WHERE expiry_date IS NULL OR expiry_date >= TRUNC(SYSDATE)`),
        conn.execute(`SELECT NVL(SUM(amount),0) AS c FROM payment WHERE payment_status = 'PAID'`),
      ]);
      res.json({
        activeResidents: residents.rows[0].C,
        households: households.rows[0].C,
        casesByStatus: cases.rows.map((r) => ({ status: r.K, count: r.C })),
        reportsByStatus: reports.rows.map((r) => ({ status: r.K, count: r.C })),
        lettersByStatus: letters.rows.map((r) => ({ status: r.K, count: r.C })),
        activeAnnouncements: announcements.rows[0].C,
        totalRevenue: payments.rows[0].C,
      });
    });
  } catch (e) {
    console.error('[api/dashboard]', e);
    res.status(500).json({ error: 'Could not load dashboard stats.' });
  }
});

// ---------------------------------------------------------------- LOOKUP
// Returns {value,label} pairs for populating <select> dropdowns for FKs.
router.get('/lookup/:table', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  const labelExpr = t.displayCols.map((c) => `NVL(TO_CHAR(${c}), '')`).join(` || ' ' || `);
  try {
    const result = await withConnection((conn) =>
      conn.execute(
        `SELECT ${t.pk} AS value, (${labelExpr} || ' (#' || ${t.pk} || ')') AS label
           FROM ${t.table} ORDER BY ${t.pk} DESC FETCH FIRST 500 ROWS ONLY`
      )
    );
    res.json(result.rows.map((r) => ({ value: r.VALUE, label: r.LABEL })));
  } catch (e) {
    console.error('[api/lookup]', e);
    res.status(500).json({ error: 'Could not load lookup list.' });
  }
});

// ------------------------------------------------------------------ LIST
router.get('/:table', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;

  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize, 10) || 20));
  const offset = (page - 1) * pageSize;
  const search = (req.query.search || '').trim();

  const textCols = t.columns.filter((c) => ['text', 'textarea'].includes(c.type)).map((c) => c.name);
  let whereClause = '';
  const binds = { offset, pageSize };
  if (search && textCols.length) {
    whereClause = 'WHERE ' + textCols.map((c, i) => `UPPER(${c}) LIKE UPPER(:s${i})`).join(' OR ');
    textCols.forEach((c, i) => { binds[`s${i}`] = `%${search}%`; });
  }

  const cols = [t.pk, ...t.columns.map((c) => c.name)].join(', ');

  try {
    await withConnection(async (conn) => {
      const countRes = await conn.execute(`SELECT COUNT(*) AS c FROM ${t.table} ${whereClause}`, binds);
      const total = countRes.rows[0].C;

      const dataRes = await conn.execute(
        `SELECT ${cols} FROM ${t.table} ${whereClause}
          ORDER BY ${t.pk} DESC OFFSET :offset ROWS FETCH NEXT :pageSize ROWS ONLY`,
        binds
      );
      res.json({ rows: dataRes.rows, total, page, pageSize });
    });
  } catch (e) {
    console.error('[api/list]', e);
    res.status(500).json({ error: 'Could not load records.' });
  }
});

// ------------------------------------------------------------- GET ONE
router.get('/:table/:id', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  const cols = [t.pk, ...t.columns.map((c) => c.name)].join(', ');
  try {
    const result = await withConnection((conn) =>
      conn.execute(`SELECT ${cols} FROM ${t.table} WHERE ${t.pk} = :id`, { id: req.params.id })
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Record not found.' });
    res.json(result.rows[0]);
  } catch (e) {
    console.error('[api/get]', e);
    res.status(500).json({ error: 'Could not load record.' });
  }
});

// -------------------------------------------------------------- CREATE
router.post('/:table', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  if (t.readOnly) return res.status(403).json({ error: `${t.label} is populated automatically and cannot be created manually.` });

  const writable = t.columns.filter((c) => !c.readOnly);
  const binds = {};
  const insertCols = [];
  const placeholders = [];

  for (const col of writable) {
    let val = req.body[col.name];
    if (val === undefined || val === '') val = col.default ?? null;
    if (val === null && col.required) {
      return res.status(400).json({ error: `${col.label} is required.` });
    }
    insertCols.push(col.name);
    placeholders.push(`:${col.name}`);
    binds[col.name] = val;
  }

  binds.newId = { dir: oracledb.BIND_OUT, type: oracledb.NUMBER };

  const sql = `INSERT INTO ${t.table} (${insertCols.join(', ')})
               VALUES (${placeholders.join(', ')})
               RETURNING ${t.pk} INTO :newId`;

  try {
    const result = await withConnection((conn) => conn.execute(sql, binds, { autoCommit: true }));
    res.status(201).json({ [t.pk]: result.outBinds.newId[0] });
  } catch (e) {
    console.error('[api/create]', e);
    res.status(400).json({ error: friendlyOracleError(e) });
  }
});

// -------------------------------------------------------------- UPDATE
router.put('/:table/:id', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  if (t.readOnly) return res.status(403).json({ error: `${t.label} cannot be edited manually.` });

  const writable = t.columns.filter((c) => !c.readOnly);
  const binds = { id: req.params.id };
  const setClauses = [];

  for (const col of writable) {
    if (!(col.name in req.body)) continue;
    let val = req.body[col.name];
    if (val === '') val = null;
    setClauses.push(`${col.name} = :${col.name}`);
    binds[col.name] = val;
  }

  if (setClauses.length === 0) return res.status(400).json({ error: 'No fields to update.' });

  const sql = `UPDATE ${t.table} SET ${setClauses.join(', ')} WHERE ${t.pk} = :id`;

  try {
    const result = await withConnection((conn) => conn.execute(sql, binds, { autoCommit: true }));
    if (result.rowsAffected === 0) return res.status(404).json({ error: 'Record not found.' });
    res.json({ ok: true });
  } catch (e) {
    console.error('[api/update]', e);
    res.status(400).json({ error: friendlyOracleError(e) });
  }
});

// -------------------------------------------------------------- DELETE
router.delete('/:table/:id', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  if (t.readOnly) return res.status(403).json({ error: `${t.label} cannot be deleted manually.` });

  try {
    const result = await withConnection((conn) =>
      conn.execute(`DELETE FROM ${t.table} WHERE ${t.pk} = :id`, { id: req.params.id }, { autoCommit: true })
    );
    if (result.rowsAffected === 0) return res.status(404).json({ error: 'Record not found.' });
    res.json({ ok: true });
  } catch (e) {
    console.error('[api/delete]', e);
    if (e.errorNum === 2292) {
      return res.status(409).json({ error: 'This record is referenced by other records and cannot be deleted.' });
    }
    res.status(400).json({ error: friendlyOracleError(e) });
  }
});

function friendlyOracleError(e) {
  if (e.errorNum === 1) return 'A record with these values already exists (unique constraint).';
  if (e.errorNum === 2291) return 'Referenced record does not exist (check your dropdown selections).';
  if (e.errorNum === 2290) return 'One of the values does not satisfy a validation rule for this field.';
  if (e.errorNum === 1400) return 'A required field is missing.';
  return e.message ? e.message.split('\n')[0] : 'Database error.';
}

module.exports = router;
