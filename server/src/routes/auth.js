const express = require('express');
const bcrypt = require('bcryptjs');
const { withConnection, oracledb } = require('../db');
const { signToken, requireAuth } = require('../auth');

const router = express.Router();

async function loadUserWithRoles(conn, username) {
  const userRes = await conn.execute(
    `SELECT user_id, resident_id, username, email, display_name, account_status, password_hash
       FROM app_user WHERE UPPER(username) = UPPER(:username)`,
    { username }
  );
  if (userRes.rows.length === 0) return null;
  const user = userRes.rows[0];

  const rolesRes = await conn.execute(
    `SELECT ar.role_name
       FROM user_role ur JOIN app_role ar ON ar.role_id = ur.role_id
      WHERE ur.user_id = :uid`,
    { uid: user.USER_ID }
  );
  user.ROLES = rolesRes.rows.map((r) => r.ROLE_NAME);
  return user;
}

// ---------------------------------------------------------------- SIGN UP
router.post('/signup', async (req, res) => {
  const { username, email, password, displayName } = req.body || {};

  if (!username || !password || password.length < 6) {
    return res.status(400).json({ error: 'Username and a password of at least 6 characters are required.' });
  }

  try {
    await withConnection(async (conn) => {
      const existing = await conn.execute(
        `SELECT user_id FROM app_user WHERE UPPER(username) = UPPER(:username) OR (email IS NOT NULL AND UPPER(email) = UPPER(:email))`,
        { username, email: email || username }
      );
      if (existing.rows.length > 0) {
        const err = new Error('That username or email is already registered.');
        err.status = 409;
        throw err;
      }

      const hash = await bcrypt.hash(password, 10);

      const insertUser = await conn.execute(
        `INSERT INTO app_user (username, email, display_name, password_hash, account_status)
         VALUES (:username, :email, :displayName, :hash, 'ACTIVE')
         RETURNING user_id INTO :newId`,
        {
          username,
          email: email || null,
          displayName: displayName || username,
          hash,
          newId: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER },
        },
        { autoCommit: false }
      );
      const newUserId = insertUser.outBinds.newId[0];

      // Every self-signed-up account gets the base RESIDENT role automatically.
      const roleRes = await conn.execute(`SELECT role_id FROM app_role WHERE role_name = 'RESIDENT'`);
      if (roleRes.rows.length > 0) {
        await conn.execute(
          `INSERT INTO user_role (user_id, role_id) VALUES (:uid, :rid)`,
          { uid: newUserId, rid: roleRes.rows[0].ROLE_ID },
          { autoCommit: false }
        );
      }

      await conn.execute(
        `INSERT INTO activity_log (user_id, activity_type, ip_address) VALUES (:uid, 'LOGIN', :ip)`,
        { uid: newUserId, ip: req.ip || null },
        { autoCommit: false }
      );

      await conn.commit();

      const token = signToken({ userId: newUserId, username, roles: ['RESIDENT'] });
      res.cookie('token', token, { httpOnly: true, sameSite: 'lax' });
      res.status(201).json({
        token,
        user: { userId: newUserId, username, email, displayName: displayName || username, roles: ['RESIDENT'] },
      });
    });
  } catch (e) {
    console.error('[auth/signup]', e);
    res.status(e.status || 500).json({ error: e.status ? e.message : 'Could not create account. Is the database reachable?' });
  }
});

// ------------------------------------------------------------------ LOGIN
router.post('/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'Username and password are required.' });

  try {
    await withConnection(async (conn) => {
      const user = await loadUserWithRoles(conn, username);
      if (!user || !user.PASSWORD_HASH) {
        return res.status(401).json({ error: 'Invalid username or password.' });
      }
      if (user.ACCOUNT_STATUS !== 'ACTIVE') {
        return res.status(403).json({ error: `Account is ${user.ACCOUNT_STATUS}. Contact an administrator.` });
      }

      const ok = await bcrypt.compare(password, user.PASSWORD_HASH);
      if (!ok) return res.status(401).json({ error: 'Invalid username or password.' });

      await conn.execute(
        `UPDATE app_user SET last_login_date = SYSDATE WHERE user_id = :uid`,
        { uid: user.USER_ID }, { autoCommit: false }
      );
      await conn.execute(
        `INSERT INTO activity_log (user_id, activity_type, ip_address) VALUES (:uid, 'LOGIN', :ip)`,
        { uid: user.USER_ID, ip: req.ip || null }, { autoCommit: false }
      );
      await conn.commit();

      const token = signToken({ userId: user.USER_ID, username: user.USERNAME, roles: user.ROLES });
      res.cookie('token', token, { httpOnly: true, sameSite: 'lax' });
      res.json({
        token,
        user: {
          userId: user.USER_ID, username: user.USERNAME, email: user.EMAIL,
          displayName: user.DISPLAY_NAME, residentId: user.RESIDENT_ID, roles: user.ROLES,
        },
      });
    });
  } catch (e) {
    console.error('[auth/login]', e);
    res.status(500).json({ error: 'Login failed. Is the database reachable?' });
  }
});

// -------------------------------------------------------------------- ME
router.get('/me', requireAuth, async (req, res) => {
  try {
    await withConnection(async (conn) => {
      const user = await loadUserWithRoles(conn, req.user.username);
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.json({
        userId: user.USER_ID, username: user.USERNAME, email: user.EMAIL,
        displayName: user.DISPLAY_NAME, residentId: user.RESIDENT_ID, roles: user.ROLES,
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
