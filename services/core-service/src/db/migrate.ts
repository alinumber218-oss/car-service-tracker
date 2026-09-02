/**
 * Minimal migration runner for the Core Service's two databases (vehicle,
 * servicelog). Executes every .sql file in each migrations subfolder, in
 * filename order.
 */
import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { serviceLogPool, vehiclePool } from './pool';

async function runFolder(pool: Pool, folder: string, label: string) {
  const dir = path.join(__dirname, 'migrations', folder);
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();

  for (const file of files) {
    const sql = fs.readFileSync(path.join(dir, file), 'utf-8');
    // eslint-disable-next-line no-console
    console.log(`[${label}] Running migration: ${file}`);
    await pool.query(sql);
  }
}

async function migrate() {
  await runFolder(vehiclePool, 'vehicle', 'vehicle-db');
  await runFolder(serviceLogPool, 'servicelog', 'servicelog-db');

  // eslint-disable-next-line no-console
  console.log('Migrations complete.');
  await vehiclePool.end();
  await serviceLogPool.end();
}

migrate().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Migration failed:', err);
  process.exit(1);
});
