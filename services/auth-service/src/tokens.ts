import crypto from 'crypto';
import jwt, { SignOptions } from 'jsonwebtoken';

export function signAccessToken(userId: string): string {
  const options: SignOptions = {
    expiresIn: (process.env.JWT_ACCESS_EXPIRES_IN || '15m') as SignOptions['expiresIn'],
  };
  return jwt.sign({ sub: userId }, process.env.JWT_ACCESS_SECRET as string, options);
}

export function signRefreshToken(userId: string): string {
  const options: SignOptions = {
    expiresIn: (process.env.JWT_REFRESH_EXPIRES_IN || '30d') as SignOptions['expiresIn'],
  };
  return jwt.sign({ sub: userId }, process.env.JWT_REFRESH_SECRET as string, options);
}

export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function accessTokenTtlSeconds(): number {
  // Best-effort parse of e.g. "15m" -> seconds, defaults to 900.
  const raw = process.env.JWT_ACCESS_EXPIRES_IN || '15m';
  const match = /^(\d+)([smhd])$/.exec(raw);
  if (!match) return 900;
  const value = parseInt(match[1], 10);
  const unit = match[2];
  const multiplier = { s: 1, m: 60, h: 3600, d: 86400 }[unit] ?? 60;
  return value * multiplier;
}
