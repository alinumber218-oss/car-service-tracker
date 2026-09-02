import { Pool } from 'pg';

export const vehiclePool = new Pool({
  connectionString: process.env.VEHICLE_DATABASE_URL,
});

export const serviceLogPool = new Pool({
  connectionString: process.env.SERVICELOG_DATABASE_URL,
});

for (const pool of [vehiclePool, serviceLogPool]) {
  pool.on('error', (err) => {
    // eslint-disable-next-line no-console
    console.error('Unexpected error on idle PostgreSQL client', err);
  });
}
