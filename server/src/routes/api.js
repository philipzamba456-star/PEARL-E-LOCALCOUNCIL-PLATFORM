const express = require('express');
const { withConnection } = require('../db');
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

router.get('/dashboard', async (req, res) => {
  try {
    await withConnection(async (client) => {
      const [residents, households, cases, reports, letters, announcements, payments] = await Promise.all([
        client.query(`SELECT COUNT(*) AS c FROM resident WHERE status = 'ACTIVE'`),
        client.query(`SELECT COUNT(*) AS c FROM household`),
        client.query(`SELECT case_status AS k, COUNT(*) AS c FROM court_case GROUP BY case_status`),
        client.query(`SELECT report_status AS k, COUNT(*) AS c FROM infrastructure_report GROUP BY report_status`),
        client.query(`SELECT request_status AS k, COUNT(*) AS c FROM letter_request GROUP BY request_status`),
        client.query(`SELECT COUNT(*) AS c FROM announcement WHERE expiry_date IS NULL OR expiry_date >= CURRENT_DATE`),
        client.query(`SELECT COALESCE(SUM(amount),0) AS c FROM payment WHERE payment_status = 'PAID'`),
      ]);
      res.json({
        activeResidents: Number(residents.rows[0].c),
        households: Number(households.rows[0].c),
        casesByStatus: cases.rows.map((r) => ({ status: r.k, count: Number(r.c) })),
        reportsByStatus: reports.rows.map((r) => ({ status: r.k, count: Number(r.c) })),
        lettersByStatus: letters.rows.map((r) => ({ status: r.k, count: Number(r.c) })),
        activeAnnouncements: Number(announcements.rows[0].c),
        totalRevenue: Number(payments.rows[0].c),
      });
    });
  } catch (e) {
    console.error('[api/dashboard]', e);
    res.status(500).json({ error: 'Could not load dashboard stats.' });
  }
});

router.get('/lookup/:table', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  const labelExpr = t.displayCols.map((c) => `COALESCE(${c}::text, '')`).join(` || ' ' || `);
  try {
    const result = await withConnection((client) =>
      client.query(
        `SELECT ${t.pk} AS value, (${labelExpr} || ' (#' || ${t.pk} || ')') AS label
           FROM ${t.table} ORDER BY ${t.pk} DESC LIMIT 500`
      )
    );
    res.json(result.rows.map((r) => ({ value: r.value, label: r.label })));
  } catch (e) {
    console.error('[api/lookup]', e);
    res.status(500).json({ error: 'Could not load lookup list.' });
  }
});

router.get('/:table', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;

  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize, 10) || 20));
  const offset = (page - 1) * pageSize;
  const search = (req.query.search || '').trim();

  const textCols = t.columns.filter((c) => ['text', 'textarea'].includes(c.type)).map((c) => c.name);
  let whereClause = '';
  const searchParams = [];
  if (search && textCols.length) {
    whereClause = 'WHERE ' + textCols.map((c, i) => `${c} ILIKE $${i + 1}`).join(' OR ');
    textCols.forEach(() => searchParams.push(`%${search}%`));
  }

  const cols = [t.pk, ...t.columns.map((c) => c.name)].join(', ');

  try {
    await withConnection(async (client) => {
      const countRes = await client.query(`SELECT COUNT(*) AS c FROM ${t.table} ${whereClause}`, searchParams);
      const total = Number(countRes.rows[0].c);

      const limitIdx = searchParams.length + 1;
      const offsetIdx = searchParams.length + 2;
      const dataRes = await client.query(
        `SELECT ${cols} FROM ${t.table} ${whereClause}
          ORDER BY ${t.pk} DESC LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
        [...searchParams, pageSize, offset]
      );
      const rows = dataRes.rows.map((row) => {
        const upper = {};
        for (const [k, v] of Object.entries(row)) upper[k.toUpperCase()] = v;
        return upper;
      });
      res.json({ rows, total, page, pageSize });
    });
  } catch (e) {
    console.error('[api/list]', e);
    res.status(500).json({ error: 'Could not load records.' });
  }
});

router.get('/:table/:id', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  const cols = [t.pk, ...t.columns.map((c) => c.name)].join(', ');
  try {
    const result = await withConnection((client) =>
      client.query(`SELECT ${cols} FROM ${t.table} WHERE ${t.pk} = $1`, [req.params.id])
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Record not found.' });
    const upper = {};
    for (const [k, v] of Object.entries(result.rows[0])) upper[k.toUpperCase()] = v;
    res.json(upper);
  } catch (e) {
    console.error('[api/get]', e);
    res.status(500).json({ error: 'Could not load record.' });
  }
});

router.post('/:table', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  if (t.readOnly) return res.status(403).json({ error: `${t.label} is populated automatically and cannot be created manually.` });

  const writable = t.columns.filter((c) => !c.readOnly);
  const insertCols = [];
  const placeholders = [];
  const values = [];

  for (const col of writable) {
    let val = req.body[col.name];
    if (val === undefined || val === '') val = col.default ?? null;
    if (val === null && col.required) {
      return res.status(400).json({ error: `${col.label} is required.` });
    }
    insertCols.push(col.name);
    values.push(val);
    placeholders.push(`$${values.length}`);
  }

  const sql = `INSERT INTO ${t.table} (${insertCols.join(', ')})
               VALUES (${placeholders.join(', ')})
               RETURNING ${t.pk}`;

  try {
    const result = await withConnection((client) => client.query(sql, values));
    res.status(201).json({ [t.pk]: result.rows[0][t.pk] });
  } catch (e) {
    console.error('[api/create]', e);
    res.status(400).json({ error: friendlyPgError(e) });
  }
});

router.put('/:table/:id', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  if (t.readOnly) return res.status(403).json({ error: `${t.label} cannot be edited manually.` });

  const writable = t.columns.filter((c) => !c.readOnly);
  const setClauses = [];
  const values = [];

  for (const col of writable) {
    if (!(col.name in req.body)) continue;
    let val = req.body[col.name];
    if (val === '') val = null;
    values.push(val);
    setClauses.push(`${col.name} = $${values.length}`);
  }

  if (setClauses.length === 0) return res.status(400).json({ error: 'No fields to update.' });

  values.push(req.params.id);
  const sql = `UPDATE ${t.table} SET ${setClauses.join(', ')} WHERE ${t.pk} = $${values.length}`;

  try {
    const result = await withConnection((client) => client.query(sql, values));
    if (result.rowCount === 0) return res.status(404).json({ error: 'Record not found.' });
    res.json({ ok: true });
  } catch (e) {
    console.error('[api/update]', e);
    res.status(400).json({ error: friendlyPgError(e) });
  }
});

router.delete('/:table/:id', async (req, res) => {
  const t = getTableOr404(req, res);
  if (!t) return;
  if (t.readOnly) return res.status(403).json({ error: `${t.label} cannot be deleted manually.` });

  try {
    const result = await withConnection((client) =>
      client.query(`DELETE FROM ${t.table} WHERE ${t.pk} = $1`, [req.params.id])
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Record not found.' });
    res.json({ ok: true });
  } catch (e) {
    console.error('[api/delete]', e);
    if (e.code === '23503') {
      return res.status(409).json({ error: 'This record is referenced by other records and cannot be deleted.' });
    }
    res.status(400).json({ error: friendlyPgError(e) });
  }
});

function friendlyPgError(e) {
  if (e.code === '23505') return 'A record with these values already exists (unique constraint).';
  if (e.code === '23503') return 'Referenced record does not exist (check your dropdown selections).';
  if (e.code === '23514') return 'One of the values does not satisfy a validation rule for this field.';
  if (e.code === '23502') return 'A required field is missing.';
  return e.message ? e.message.split('\n')[0] : 'Database error.';
}

module.exports = router;
