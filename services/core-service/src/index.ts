import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import helmet from 'helmet';
import vehicleRoutes from './routes/vehicles';
import serviceLogRoutes from './routes/serviceLogs';

dotenv.config();

const app = express();

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'core-service' });
});

app.use('/vehicles', vehicleRoutes);
app.use('/service-logs', serviceLogRoutes);

// Generic error handler - keep last
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  // eslint-disable-next-line no-console
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const port = process.env.PORT || 4002;
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`core-service listening on port ${port}`);
});
