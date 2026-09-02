process.env.JWT_ACCESS_SECRET = 'test-access-secret';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
process.env.JWT_ACCESS_EXPIRES_IN = '15m';

import jwt from 'jsonwebtoken';
import { accessTokenTtlSeconds, hashToken, signAccessToken, signRefreshToken } from './tokens';

describe('token helpers', () => {
  it('signs an access token that verifies with the access secret', () => {
    const token = signAccessToken('user-123');
    const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET as string) as { sub: string };
    expect(payload.sub).toBe('user-123');
  });

  it('signs a refresh token that verifies with the refresh secret', () => {
    const token = signRefreshToken('user-456');
    const payload = jwt.verify(token, process.env.JWT_REFRESH_SECRET as string) as { sub: string };
    expect(payload.sub).toBe('user-456');
  });

  it('produces a stable sha256 hash for the same token', () => {
    const hashA = hashToken('some-refresh-token');
    const hashB = hashToken('some-refresh-token');
    expect(hashA).toBe(hashB);
    expect(hashA).toHaveLength(64);
  });

  it('parses "15m" into 900 seconds', () => {
    expect(accessTokenTtlSeconds()).toBe(900);
  });
});
