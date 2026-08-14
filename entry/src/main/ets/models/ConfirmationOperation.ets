import { ConfirmationRequest, ConfirmationRequestStatus } from './ConfirmationRequest'
import { OperationReceipt } from './Operation'

export interface ConfirmationDecisionRequest {
  status: ConfirmationRequestStatus
}

export interface ConfirmationDecisionResult {
  request: ConfirmationRequest
  operation: OperationReceipt
}
