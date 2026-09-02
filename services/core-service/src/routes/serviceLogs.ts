import { Router } from 'express';
import { z } from 'zod';
import { serviceLogPool, vehiclePool } from '../db/pool';
import { AuthedRequest, verifyAccessToken } from '../middleware/verifyToken';
import { publishServiceLogCreated } from '../events/publisher';

const router = Router();
router.use(verifyAccessToken);

const createServiceLogSchema = z.object({
  vehicleId: z.string().uuid(),
  serviceTypeId: z.number().int().optional(),
  customTypeName: z.string().max(100).optional(),
  serviceDate: z.string(), // ISO date string, e.g. "2026-05-01"
  mileageAtService: z.number().int().min(0).optional(),
  cost: z.number().min(0).optional(),
  currency: z.string().length(3).optional(),
  shopName: z.string().max(150).optional(),
  notes: z.string().optional(),
});

function toServiceLog(row: any) {
  return {
    id: row.id,
    vehicleId: row.vehicle_id,
    userId: row.user_id,
    serviceTypeId: row.service_type_id,
    customTypeName: row.custom_type_name,
    serviceDate: row.service_date,
    mileageAtService: row.mileage_at_service,
    cost: row.cost !== null ? Number(row.cost) : null,
    currency: row.currency,
    shopName: row.shop_name,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// GET /service-logs?vehicleId=... - list logs for a vehicle owned by the user
router.get('/', async (req: AuthedRequest, res) => {
  const vehicleId = req.query.vehicleId as string | undefined;
  if (!vehicleId) return res.status(400).json({ error: 'vehicleId query param is required' });

  const owned = await vehiclePool.query(
    `SELECT id FROM vehicles WHERE id = $1 AND user_id = $2`,
    [vehicleId, req.userId],
  );
  if (owned.rows.length === 0) return res.status(404).json({ error: 'Vehicle not found' });

  const result = await serviceLogPool.query(
    `SELECT * FROM service_logs WHERE vehicle_id = $1 ORDER BY service_date DESC`,
    [vehicleId],
  );
  res.json({ serviceLogs: result.rows.map(toServiceLog) });
});

// GET /service-logs/types - list available service type presets
router.get('/types', async (_req, res) => {
  const result = await serviceLogPool.query(
    `SELECT * FROM service_types ORDER BY category, name`,
  );
  res.json({
    serviceTypes: result.rows.map((r) => ({
      id: r.id,
      name: r.name,
      category: r.category,
      isCustom: r.is_custom,
    })),
  });
});

// POST /service-logs - create a new service log entry
router.post('/', async (req: AuthedRequest, res) => {
  const parsed = createServiceLogSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
  const v = parsed.data;

  const owned = await vehiclePool.query(
    `SELECT id FROM vehicles WHERE id = $1 AND user_id = $2`,
    [v.vehicleId, req.userId],
  );
  if (owned.rows.length === 0) return res.status(404).json({ error: 'Vehicle not found' });

  const result = await serviceLogPool.query(
    `INSERT INTO service_logs
       (vehicle_id, user_id, service_type_id, custom_type_name, service_date,
        mileage_at_service, cost, currency, shop_name, notes)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     RETURNING *`,
    [
      v.vehicleId,
      req.userId,
      v.serviceTypeId ?? null,
      v.customTypeName ?? null,
      v.serviceDate,
      v.mileageAtService ?? null,
      v.cost ?? null,
      v.currency ?? 'EUR',
      v.shopName ?? null,
      v.notes ?? null,
    ],
  );

  const log = result.rows[0];

  // Best-effort event publish - Reminder Service consumes this to recalculate due dates.
  await publishServiceLogCreated({
    eventType: 'service_log.created',
    vehicleId: log.vehicle_id,
    serviceTypeId: log.service_type_id,
    serviceDate: log.service_date,
    mileageAtService: log.mileage_at_service,
  });

  res.status(201).json({ serviceLog: toServiceLog(log) });
});

export default router;
