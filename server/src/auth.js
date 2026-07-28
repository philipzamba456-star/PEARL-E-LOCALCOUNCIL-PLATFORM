const jwt = require('jsonwebtoken');

const SECRET = process.env.JWT_SECRET || 'change-this-secret-in-.env';
const EXPIRES_IN = process.env.JWT_EXPIRES_IN || '12h';

function signToken(payload) {
  return jwt.sign(payload, SECRET, { expiresIn: EXPIRES_IN });
}

function verifyToken(token) {
  return jwt.verify(token, SECRET);
}

/** Reads Bearer token OR httpOnly cookie 'token'; attaches req.user. */
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const bearer = header.startsWith('Bearer ') ? header.slice(7) : null;
  const token = bearer || req.cookies?.token;

  if (!token) return res.status(401).json({ error: 'Not authenticated' });

  try {
    req.user = verifyToken(token);
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Invalid or expired session' });
  }
}

/** Optional auth: attaches req.user if present, never blocks the request. */
function optionalAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const bearer = header.startsWith('Bearer ') ? header.slice(7) : null;
  const token = bearer || req.cookies?.token;
  if (token) {
    try { req.user = verifyToken(token); } catch (e) { /* ignore */ }
  }
  next();
}

function requireAdmin(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Not authenticated' });
  if (!req.user.roles?.some((r) => ['SUPER_ADMINISTRATOR', 'LC3_ADMINISTRATOR'].includes(r))) {
    return res.status(403).json({ error: 'Administrator access required' });
  }
  next();
}

module.exports = { signToken, verifyToken, requireAuth, optionalAuth, requireAdmin };
