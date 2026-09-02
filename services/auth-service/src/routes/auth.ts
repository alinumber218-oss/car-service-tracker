import bcrypt from 'bcrypt';
import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool';
import { verifyAccessToken, AuthedRequest } from '../middleware/verifyToken';
import {
  accessTokenTtlSeconds,
  hashToken,
  signAccessToken,
  signRefreshToken,
} from '../tokens';

const router = Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  displayName: z.string().max(100).optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

const refreshSchema = z.object({
  refreshToken: z.string(),
});

function toPublicUser(row: any) {
  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name,
    authProvider: row.auth_provider,
    emailVerified: row.email_verified,
    createdAt: row.created_at,
  };
}

router.post('/register', async (req, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { email, password, displayName } = parsed.data;

  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (existing.rows.length > 0) {
    return res.status(409).json({ error: 'An account with this email already exists' });
  }

  const passwordHash = await bcrypt.hash(password, 12);

  const result = await pool.query(
    `INSERT INTO users (email, password_hash, display_name, auth_provider)
     VALUES ($1, $2, $3, 'password')
     RETURNING id, email, display_name, auth_provider, email_verified, created_at`,
    [email, passwordHash, displayName ?? null],
  );

  const user = result.rows[0];
  const accessToken = signAccessToken(user.id);
  const refreshToken = signRefreshToken(user.id);

  await pool.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, now() + interval '30 days')`,
    [user.id, hashToken(refreshToken)],
  );

  return res.status(201).json({
    user: toPublicUser(user),
    tokens: { accessToken, refreshToken, expiresIn: accessTokenTtlSeconds() },
  });
});

router.post('/login', async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { email, password } = parsed.data;

  const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  const user = result.rows[0];

  if (!user || !user.password_hash) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  const accessToken = signAccessToken(user.id);
  const refreshToken = signRefreshToken(user.id);

  await pool.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, now() + interval '30 days')`,
    [user.id, hashToken(refreshToken)],
  );

  return res.json({
    user: toPublicUser(user),
    tokens: { accessToken, refreshToken, expiresIn: accessTokenTtlSeconds() },
  });
});

router.post('/refresh', async (req, res) => {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  const { refreshToken } = parsed.data;

  let payload: { sub: string };
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const jwt = require('jsonwebtoken');
    payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET as string);
  } catch {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }

  const tokenHash = hashToken(refreshToken);
  const stored = await pool.query(
    `SELECT * FROM refresh_tokens WHERE user_id = $1 AND token_hash = $2 AND revoked_at IS NULL AND expires_at > now()`,
    [payload.sub, tokenHash],
  );

  if (stored.rows.length === 0) {
    return res.status(401).json({ error: 'Refresh token not recognized or already revoked' });
  }

  const accessToken = signAccessToken(payload.sub);
  return res.json({ accessToken, expiresIn: accessTokenTtlSeconds() });
});

router.get('/me', verifyAccessToken, async (req: AuthedRequest, res) => {
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
  const user = result.rows[0];
  if (!user) return res.status(404).json({ error: 'User not found' });
  return res.json({ user: toPublicUser(user) });
});

export default router;
