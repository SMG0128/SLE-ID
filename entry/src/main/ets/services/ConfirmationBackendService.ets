import { ConfirmationDecisionResult } from '../models/ConfirmationOperation'
import {
  ConfirmationRequest,
  ConfirmationRequestStatus
} from '../models/ConfirmationRequest'

export interface ConfirmationBackendService {
  listPendingConfirmations(): Promise<ConfirmationRequest[]>
  decideConfirmation(
    requestId: string,
    status: ConfirmationRequestStatus
  ): Promise<ConfirmationDecisionResult>
}
