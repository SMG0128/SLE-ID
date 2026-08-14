import { ConfirmationRequest, ConfirmationRequestStatus } from '../models/ConfirmationRequest'

export interface ConfirmationService {
  listConfirmationRequests(): Promise<ConfirmationRequest[]>
  getConfirmationRequest(requestId: string): Promise<ConfirmationRequest | null>
  resolveConfirmation(requestId: string, status: ConfirmationRequestStatus): Promise<ConfirmationRequest>
}
