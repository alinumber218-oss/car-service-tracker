import { api } from './api';

export interface CreateVehiclePayload {
  nickname?: string;
  make: string;
  model: string;
  year: number;
  currentMileage?: number;
  mileageUnit?: 'km' | 'mi';
}

export async function listVehicles() {
  const { data } = await api.get('/vehicles');
  return data.vehicles;
}

export async function createVehicle(payload: CreateVehiclePayload) {
  const { data } = await api.post('/vehicles', payload);
  return data.vehicle;
}

export async function listServiceLogs(vehicleId: string) {
  const { data } = await api.get('/service-logs', { params: { vehicleId } });
  return data.serviceLogs;
}
