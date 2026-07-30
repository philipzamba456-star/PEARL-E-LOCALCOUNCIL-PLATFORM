const express = require('express');
const bcrypt = require('bcryptjs');
const { withConnection } = require('../db');
const { signToken, requireAuth } = require('../auth');

const router = express.Router();

async function loadUserWithRoles(client, username) {
  const userRes = await client.query(
    `SELECT user_id, resident_id, username, email, display_name, account_status, password_hash
       FROM app_user WHERE UPPER(username) = UPPER($1)`,
    [username]
  );
  if (userRes.rows.length === 0) return null;
  const user = userRes.rows[0];

  const rolesRes = await client.query(
    `SELECT ar.role_name
       FROM user_role ur JOIN app_role ar ON ar.role_id = ur.role_id
      WHERE ur.user_id = $1`,
    [user.user_id]
  );
  user.roles = rolesRes.rows.map((r) => r.role_name);
  return user;
}

router.post('/signup', async (req, res) => {
  const { username, email, password, displayName } = req.body || {};

  if (!username || !password || password.length < 6) {
    return res.status(400).json({ error: 'Username and a password of at least 6 characters are required.' });
  }

  try {
    await withConnection(async (client) => {
      await client.query('BEGIN');
      try {
        const existing = await client.query(
          `SELECT user_id FROM app_user WHERE UPPER(username) = UPPER($1) OR (email IS NOT NULL AND UPPER(email) = UPPER($2))`,
          [username, email || username]
        );
        if (existing.rows.length > 0) {
          const err = new Error('That username or email is already registered.');
          err.status = 409;
          throw err;
        }

        const hash = await bcrypt.hash(password, 10);

        const insertUser = await client.query(
          `INSERT INTO app_user (username, email, display_name, password_hash, account_status)
           VALUES ($1, $2, $3, $4, 'ACTIVE') RETURNING user_id`,
          [username, email || null, displayName || username, hash]
        );
        const newUserId = insertUser.rows[0].user_id;

        const roleRes = await client.query(`SELECT role_id FROM app_role WHERE role_name = 'RESIDENT'`);
        if (roleRes.rows.length > 0) {
          await client.query(`INSERT INTO user_role (user_id, role_id) VALUES ($1, $2)`, [newUserId, roleRes.rows[0].role_id]);
        }

        await client.query(
          `INSERT INTO activity_log (user_id, activity_type, ip_address) VALUES ($1, 'LOGIN', $2)`,
          [newUserId, req.ip || null]
        );

        await client.query('COMMIT');

        const token = signToken({ userId: newUserId, username, roles: ['RESIDENT'] });
        res.cookie('token', token, { httpOnly: true, sameSite: 'lax' });
        res.status(201).json({
          token,
          user: { userId: newUserId, username, email, displayName: displayName || username, roles: ['RESIDENT'] },
        });
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      }
    });
  } catch (e) {
    console.error('[auth/signup]', e);
    res.status(e.status || 500).json({ error: e.status ? e.message : 'Could not create account. Is the database reachable?' });
  }
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'Username and password are required.' });

  try {
    await withConnection(async (client) => {
      const user = await loadUserWithRoles(client, username);
      if (!user || !user.password_hash) {
        return res.status(401).json({ error: 'Invalid username or password.' });
      }
      if (user.account_status !== 'ACTIVE') {
        return res.status(403).json({ error: `Account is ${user.account_status}. Contact an administrator.` });
      }

      const ok = await bcrypt.compare(password, user.password_hash);
      if (!ok) return res.status(401).json({ error: 'Invalid username or password.' });

      await client.query(`UPDATE app_user SET last_login_date = CURRENT_TIMESTAMP WHERE user_id = $1`, [user.user_id]);
      await client.query(
        `INSERT INTO activity_log (user_id, activity_type, ip_address) VALUES ($1, 'LOGIN', $2)`,
        [user.user_id, req.ip || null]
      );

      const token = signToken({ userId: user.user_id, username: user.username, roles: user.roles });
      res.cookie('token', token, { httpOnly: true, sameSite: 'lax' });
      res.json({
        token,
        user: {
          userId: user.user_id, username: user.username, email: user.email,
          displayName: user.display_name, residentId: user.resident_id, roles: user.roles,
        },
      });
    });
  } catch (e) {
    console.error('[auth/login]', e);
    res.status(500).json({ error: 'Login failed. Is the database reachable?' });
  }
});

router.get('/me', requireAuth, async (req, res) => {
  try {
    await withConnection(async (client) => {
      const user = await loadUserWithRoles(client, req.user.username);
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.json({
        userId: user.user_id, username: user.username, email: user.email,
        displayName: user.display_name, residentId: user.resident_id, roles: user.roles,
      });
    });
  } catch (e) {
    console.error('[auth/me]', e);
    res.status(500).json({ error: 'Could not load profile.' });
  }
});

router.post('/logout', (req, res) => {
  res.clearCookie('token');
  res.json({ ok: true });
});

module.exports = router;
