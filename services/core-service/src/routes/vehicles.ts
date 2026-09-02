import { Router } from 'express';
import { z } from 'zod';
import { vehiclePool } from '../db/pool';
import { AuthedRequest, verifyAccessToken } from '../middleware/verifyToken';

const router = Router();
router.use(verifyAccessToken);

const createVehicleSchema = z.object({
  nickname: z.string().max(100).optional(),
  make: z.string().min(1).max(50),
  model: z.string().min(1).max(50),
  year: z.number().int().min(1900).max(2100),
  vin: z.string().max(17).optional(),
  licensePlate: z.string().max(20).optional(),
  color: z.string().max(30).optional(),
  currentMileage: z.number().int().min(0).optional(),
  mileageUnit: z.enum(['km', 'mi']).optional(),
});

const updateMileageSchema = z.object({
  mileage: z.number().int().min(0),
  source: z.enum(['manual', 'service_log', 'obd2']).optional(),
});

function toVehicle(row: any) {
  return {
    id: row.id,
    userId: row.user_id,
    nickname: row.nickname,
    make: row.make,
    model: row.model,
    year: row.year,
    vin: row.vin,
    licensePlate: row.license_plate,
    color: row.color,
    photoUrl: row.photo_url,
    currentMileage: row.current_mileage,
    mileageUnit: row.mileage_unit,
    isArchived: row.is_archived,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// GET /vehicles - list the authenticated user's vehicles
router.get('/', async (req: AuthedRequest, res) => {
  const result = await vehiclePool.query(
    `SELECT * FROM vehicles WHERE user_id = $1 AND is_archived = FALSE ORDER BY created_at DESC`,
    [req.userId],
  );
  res.json({ vehicles: result.rows.map(toVehicle) });
});

// POST /vehicles - create a vehicle
router.post('/', async (req: AuthedRequest, res) => {
  const parsed = createVehicleSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const v = parsed.data;
  const result = await vehiclePool.query(
    `INSERT INTO vehicles
       (user_id, nickname, make, model, year, vin, license_plate, color, current_mileage, mileage_unit)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     RETURNING *`,
    [
      req.userId,
      v.nickname ?? null,
      v.make,
      v.model,
      v.year,
      v.vin ?? null,
      v.licensePlate ?? null,
      v.color ?? null,
      v.currentMileage ?? 0,
      v.mileageUnit ?? 'km',
    ],
  );

  res.status(201).json({ vehicle: toVehicle(result.rows[0]) });
});

// GET /vehicles/:id
router.get('/:id', async (req: AuthedRequest, res) => {
  const result = await vehiclePool.query(
    `SELECT * FROM vehicles WHERE id = $1 AND user_id = $2`,
    [req.params.id, req.userId],
  );
  if (result.rows.length === 0) return res.status(404).json({ error: 'Vehicle not found' });
  res.json({ vehicle: toVehicle(result.rows[0]) });
});

// POST /vehicles/:id/mileage - log a new mileage reading
router.post('/:id/mileage', async (req: AuthedRequest, res) => {
  const parsed = updateMileageSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const owned = await vehiclePool.query(
    `SELECT id FROM vehicles WHERE id = $1 AND user_id = $2`,
    [req.params.id, req.userId],
  );
  if (owned.rows.length === 0) return res.status(404).json({ error: 'Vehicle not found' });

  const { mileage, source } = parsed.data;

  await vehiclePool.query(
    `UPDATE vehicles SET current_mileage = $1, updated_at = now() WHERE id = $2`,
    [mileage, req.params.id],
  );

  const result = await vehiclePool.query(
    `INSERT INTO mileage_history (vehicle_id, mileage, source)
     VALUES ($1, $2, $3) RETURNING *`,
    [req.params.id, mileage, source ?? 'manual'],
  );

  res.status(201).json({
    mileageEntry: {
      id: result.rows[0].id,
      vehicleId: result.rows[0].vehicle_id,
      mileage: result.rows[0].mileage,
      recordedAt: result.rows[0].recorded_at,
      source: result.rows[0].source,
    },
  });
});

export default router;
