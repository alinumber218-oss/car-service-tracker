export type MileageUnit = 'km' | 'mi';

export interface Vehicle {
  id: string;
  userId: string;
  nickname?: string | null;
  make: string;
  model: string;
  year: number;
  vin?: string | null;
  licensePlate?: string | null;
  color?: string | null;
  photoUrl?: string | null;
  currentMileage: number;
  mileageUnit: MileageUnit;
  isArchived: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CreateVehicleRequest {
  nickname?: string;
  make: string;
  model: string;
  year: number;
  vin?: string;
  licensePlate?: string;
  color?: string;
  currentMileage?: number;
  mileageUnit?: MileageUnit;
}

export interface UpdateMileageRequest {
  mileage: number;
  source?: 'manual' | 'service_log' | 'obd2';
}
