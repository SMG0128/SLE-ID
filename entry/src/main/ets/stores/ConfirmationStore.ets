import {
  cloneConfirmationRequest,
  ConfirmationDirection,
  ConfirmationRequest,
  ConfirmationRequestStatus,
  ConfirmationTransitionResult,
  transitionConfirmationRequest
} from '../models/ConfirmationRequest'
import {
  isAuthoritativeSuccess,
  OperationAuthority,
  OperationReceipt,
  OperationState
} from '../models/Operation'

@Observed
export class ConfirmationStore {
  private static instance: ConfirmationStore

  requests: ConfirmationRequest[] = []
  lastOperation: OperationReceipt = {
    operationId: '',
    state: OperationState.IDLE,
    authority: OperationAuthority.NONE,
    verificationRequired: false,
    receiptId: '',
    errorCode: '',
    updatedAt: ''
  }

  static getInstance(): ConfirmationStore {
    if (!ConfirmationStore.instance) {
      ConfirmationStore.instance = new ConfirmationStore()
    }
    return ConfirmationStore.instance
  }

  receiveLocalMockRequest(
    digitalCardId: string,
    permissionId: string,
    randomCode: string
  ): ConfirmationRequest {
    const requestId: string =
      `mock-confirm-${digitalCardId}-${randomCode || 'no-code'}`
    const existing: ConfirmationRequest | null = this.getRequest(requestId)
    if (existing) {
      return existing
    }
    const now: Date = new Date()
    const request: ConfirmationRequest = {
      requestId: requestId,
      digitalCardId: digitalCardId,
      permissionId: permissionId,
      detectorId: 'mock-detector-local',
      checkpointName: 'Local mock checkpoint',
      eventId: `mock-event-${randomCode || digitalCardId}`,
      action: 'mock-access',
      direction: ConfirmationDirection.UNKNOWN,
      randomCode: randomCode,
      status: ConfirmationRequestStatus.PENDING,
      createdAt: now.toISOString(),
      expiresAt: new Date(now.getTime() + 300000).toISOString(),
      resolvedAt: ''
    }
    this.requests.push(request)
    this.requests = this.requests.slice()
    return cloneConfirmationRequest(request)
  }

  approveLocalMock(requestId: string): ConfirmationTransitionResult | null {
    const index: number = this.findRequestIndex(requestId)
    if (index < 0) {
      return null
    }
    const resolvedAt: string = new Date().toISOString()
    const transition: ConfirmationTransitionResult =
      transitionConfirmationRequest(
        this.requests[index],
        ConfirmationRequestStatus.APPROVED,
        resolvedAt
      )
    this.requests[index] = transition.request
    this.requests = this.requests.slice()
    this.lastOperation = {
      operationId: `confirmation-${requestId}`,
      state: transition.accepted ?
        OperationState.ACKNOWLEDGED : OperationState.FAILED,
      authority: OperationAuthority.LOCAL,
      verificationRequired: false,
      receiptId: transition.accepted ? `local-${requestId}` : '',
      errorCode: transition.accepted ? '' : transition.reason,
      updatedAt: resolvedAt
    }
    return transition
  }

  hasAuthoritativeLocalResult(requestId: string): boolean {
    const request: ConfirmationRequest | null = this.getRequest(requestId)
    return request !== null &&
      request.status === ConfirmationRequestStatus.APPROVED &&
      this.lastOperation.operationId === `confirmation-${requestId}` &&
      isAuthoritativeSuccess(this.lastOperation)
  }

  getRequest(requestId: string): ConfirmationRequest | null {
    const index: number = this.findRequestIndex(requestId)
    return index >= 0 ? cloneConfirmationRequest(this.requests[index]) : null
  }

  private findRequestIndex(requestId: string): number {
    let result: number = -1
    this.requests.forEach((request: ConfirmationRequest, index: number) => {
      if (request.requestId === requestId) {
        result = index
      }
    })
    return result
  }
}
