export enum ConfirmationRequestStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  EXPIRED = 'expired',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
}

export interface ConfirmationRequest {
  id: string
  digitalCardId: string
  authorizationId: string
  checkpointId: string
  checkpointName: string
  eventId: string
  randomCode: string
  status: ConfirmationRequestStatus
  createdAt: string
  expiresAt: string
  resolvedAt: string
}
