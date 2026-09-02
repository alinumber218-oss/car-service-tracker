import axios from 'axios';

/**
 * Base URL for the API Gateway.
 *
 * IMPORTANT for Android emulator: "localhost" from the emulator's
 * perspective is the emulator itself, not your host machine. Use
 * 10.0.2.2 instead when running against services on your own computer
 * (docker-compose or `kubectl port-forward`). See mobile/README.md
 * "Connecting to the backend from the emulator" for details.
 *
 *   Android emulator:  http://10.0.2.2:8080
 *   iOS simulator:     http://localhost:8080  (simulator shares the host's network)
 *   Physical device:   http://<your-computer-LAN-IP>:8080
 */
const BASE_URL = process.env.API_BASE_URL || 'http://10.0.2.2:8080';

export const api = axios.create({
  baseURL: BASE_URL,
  timeout: 10000,
});

let accessToken: string | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
}

api.interceptors.request.use((config) => {
  if (accessToken) {
    config.headers = config.headers ?? {};
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});
