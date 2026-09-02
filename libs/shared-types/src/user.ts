export type AuthProvider = 'password' | 'google' | 'apple';

export interface User {
  id: string;
  email: string;
  displayName?: string | null;
  authProvider: AuthProvider;
  emailVerified: boolean;
  createdAt: string;
}

export interface RegisterRequest {
  email: string;
  password: string;
  displayName?: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface AuthResponse {
  user: User;
  tokens: AuthTokens;
}
