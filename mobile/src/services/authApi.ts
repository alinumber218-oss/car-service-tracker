import { api, setAccessToken } from './api';

export interface LoginPayload {
  email: string;
  password: string;
}

export interface RegisterPayload extends LoginPayload {
  displayName?: string;
}

export async function login(payload: LoginPayload) {
  const { data } = await api.post('/auth/login', payload);
  setAccessToken(data.tokens.accessToken);
  return data;
}

export async function register(payload: RegisterPayload) {
  const { data } = await api.post('/auth/register', payload);
  setAccessToken(data.tokens.accessToken);
  return data;
}

export async function fetchMe() {
  const { data } = await api.get('/auth/me');
  return data.user;
}
