export interface ServiceType {
  id: number;
  name: string;
  category?: string | null;
  isCustom: boolean;
}

export interface ServiceLog {
  id: string;
  vehicleId: string;
  userId: string;
  serviceTypeId?: number | null;
  customTypeName?: string | null;
  serviceDate: string;
  mileageAtService?: number | null;
  cost?: number | null;
  currency: string;
  shopName?: string | null;
  notes?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateServiceLogRequest {
  vehicleId: string;
  serviceTypeId?: number;
  customTypeName?: string;
  serviceDate: string;
  mileageAtService?: number;
  cost?: number;
  currency?: string;
  shopName?: string;
  notes?: string;
}

/** Event published to the message bus when a new service log is created. */
export interface ServiceLogCreatedEvent {
  eventType: 'service_log.created';
  vehicleId: string;
  serviceTypeId?: number | null;
  serviceDate: string;
  mileageAtService?: number | null;
}
