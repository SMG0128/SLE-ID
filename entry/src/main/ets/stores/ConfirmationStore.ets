import {
  cloneConfirmationRequest,
  ConfirmationDirection,
  ConfirmationRequest,
  ConfirmationRequestStatus,
  ConfirmationTransitionReason,
  ConfirmationTransitionResult,
  isTerminalConfirmationStatus,
  transitionConfirmationRequest
} from '../models/ConfirmationRequest'
import {
  CONFIRMATION_SCHEMA_VERSION,
  ConfirmationPersistenceState
} from '../models/ConfirmationPersistence'
import { ConfirmationDecisionResult } from '../models/ConfirmationOperation'
import {
  createPendingOperation,
  isAuthoritativeSuccess,
  OperationAuthority,
  OperationReceipt,
  OperationState
} from '../models/Operation'
import { ConfirmationBackendService } from '../services/ConfirmationBackendService'
import { ConfirmationPersistenceService } from '../services/ConfirmationPersistenceService'

export type PendingConfirmationListener = (request: ConfirmationRequest | null) => void

@Observed
export class ConfirmationStore {
  private static instance: ConfirmationStore

  requests: ConfirmationRequest[] = []
  isSubmitting: boolean = false
  isOffline: boolean = false
  errorMessage: string = ''
  submittingRequestId: string = ''
  lastOperation: OperationReceipt = {
    operationId: '',
    state: OperationState.IDLE,
    authority: OperationAuthority.NONE,
    verificationRequired: false,
    receiptId: '',
    errorCode: '',
    updatedAt: ''
  }

  private readonly backendService: ConfirmationBackendService | null
  private readonly persistenceService: ConfirmationPersistenceService | null
  private pendingListener: PendingConfirmationListener | null = null

  constructor(
    backendService: ConfirmationBackendService | null = null,
    persistenceService: ConfirmationPersistenceService | null = null
  ) {
    this.backendService = backendService
    this.persistenceService = persistenceService
  }

  static getInstance(): ConfirmationStore {
    if (!ConfirmationStore.instance) {
      ConfirmationStore.instance = new ConfirmationStore()
    }
    return ConfirmationStore.instance
  }

  static configureProduction(
    backendService: ConfirmationBackendService,
    persistenceService: ConfirmationPersistenceService
  ): ConfirmationStore {
    ConfirmationStore.instance = new ConfirmationStore(
      backendService,
      persistenceService
    )
    return ConfirmationStore.instance
  }

  async initialize(): Promise<void> {
    if (this.persistenceService) {
      try {
        const persisted: ConfirmationPersistenceState =
          await this.persistenceService.load()
        this.requests = persisted.requests
        this.lastOperation = persisted.lastOperation
        await this.expirePending(Date.now())
      } catch (error) {
        this.errorMessage = 'Unable to load saved confirmations'
      }
    }
    await this.recoverPending()
  }

  setPendingListener(listener: PendingConfirmationListener | null): void {
    this.pendingListener = listener
    this.notifyPendingListener()
  }

  activePendingRequest(): ConfirmationRequest | null {
    let result: ConfirmationRequest | null = null
    this.requests.forEach((request: ConfirmationRequest) => {
      if (!result && request.status === ConfirmationRequestStatus.PENDING &&
        Date.parse(request.expiresAt) > Date.now()) {
        result = request
      }
    })
    return result ? cloneConfirmationRequest(result) : null
  }

  async receiveProductionRequest(
    request: ConfirmationRequest
  ): Promise<ConfirmationRequest> {
    await this.mergePendingRequests([request])
    const stored: ConfirmationRequest | null = this.getRequest(request.requestId)
    return stored ? stored : cloneConfirmationRequest(request)
  }

  async mergePendingRequests(incoming: ConfirmationRequest[]): Promise<number> {
    let added: number = 0
    const now: string = new Date().toISOString()
    incoming.forEach((candidate: ConfirmationRequest) => {
      const normalized: ConfirmationRequest = cloneConfirmationRequest(candidate)
      if (normalized.status === ConfirmationRequestStatus.PENDING &&
        Date.parse(normalized.expiresAt) <= Date.parse(now)) {
        normalized.status = ConfirmationRequestStatus.TIMEOUT
        normalized.resolvedAt = now
      }
      const index: number = this.findRequestIndex(normalized.requestId)
      if (index < 0) {
        this.requests.push(normalized)
        added++
        return
      }
      const existing: ConfirmationRequest = this.requests[index]
      if (isTerminalConfirmationStatus(existing.status)) {
        return
      }
      if (normalized.status === ConfirmationRequestStatus.PENDING) {
        this.requests[index] = normalized
        return
      }
      const transition: ConfirmationTransitionResult =
        transitionConfirmationRequest(existing, normalized.status, now)
      if (transition.accepted ||
        transition.reason === ConfirmationTransitionReason.EXPIRED) {
        this.requests[index] = transition.request
      }
    })
    this.requests = this.requests.slice()
    await this.persist()
    this.notifyPendingListener()
    return added
  }

  async recoverPending(): Promise<void> {
    if (!this.backendService) {
      return
    }
    try {
      const pending: ConfirmationRequest[] =
        await this.backendService.listPendingConfirmations()
      await this.mergePendingRequests(pending)
      this.isOffline = false
      this.errorMessage = ''
    } catch (error) {
      this.isOffline = true
      this.errorMessage = 'Unable to recover pending confirmations'
    }
  }

  async submitDecision(
    requestId: string,
    status: ConfirmationRequestStatus
  ): Promise<boolean> {
    if (!this.backendService) {
      const local: ConfirmationTransitionResult | null =
        this.resolveLocalMock(requestId, status)
      return local !== null && local.accepted &&
        isAuthoritativeSuccess(this.lastOperation)
    }
    if (status !== ConfirmationRequestStatus.APPROVED &&
      status !== ConfirmationRequestStatus.REJECTED &&
      status !== ConfirmationRequestStatus.TIMEOUT &&
      status !== ConfirmationRequestStatus.OFFLINE) {
      return false
    }
    const index: number = this.findRequestIndex(requestId)
    if (index < 0 || this.isSubmitting) {
      return false
    }
    const now: string = new Date().toISOString()
    const preflight: ConfirmationTransitionResult =
      transitionConfirmationRequest(this.requests[index], status, now)
    if (!preflight.accepted) {
      if (preflight.reason === ConfirmationTransitionReason.EXPIRED) {
        this.requests[index] = preflight.request
        this.requests = this.requests.slice()
        this.lastOperation = this.failedOperation(
          requestId,
          ConfirmationTransitionReason.EXPIRED,
          now
        )
        await this.persist()
        this.notifyPendingListener()
      }
      return false
    }

    this.isSubmitting = true
    this.submittingRequestId = requestId
    this.errorMessage = ''
    this.lastOperation = createPendingOperation(
      `confirmation-${requestId}`,
      OperationAuthority.BACKEND,
      false,
      now
    )
    try {
      const result: ConfirmationDecisionResult =
        await this.backendService.decideConfirmation(requestId, status)
      if (!isAuthoritativeSuccess(result.operation) ||
        result.operation.authority !== OperationAuthority.BACKEND ||
        result.request.requestId !== requestId ||
        result.request.status !== status) {
        throw new Error('Invalid confirmation acknowledgement')
      }
      const acknowledged: ConfirmationTransitionResult =
        transitionConfirmationRequest(
          this.requests[index],
          result.request.status,
          result.request.resolvedAt || new Date().toISOString()
        )
      if (!acknowledged.accepted) {
        throw new Error('Confirmation acknowledgement violates terminal state')
      }
      this.requests[index] = acknowledged.request
      this.requests = this.requests.slice()
      this.lastOperation = result.operation
      this.isOffline = false
      await this.persist()
      this.notifyPendingListener()
      return true
    } catch (error) {
      const failedAt: string = new Date().toISOString()
      this.lastOperation = this.failedOperation(
        requestId,
        'BACKEND_DECISION_FAILED',
        failedAt
      )
      this.isOffline = true
      this.errorMessage = 'Backend did not acknowledge the decision'
      await this.persist()
      return false
    } finally {
      this.isSubmitting = false
      this.submittingRequestId = ''
    }
  }

  async expirePending(nowMillis: number): Promise<void> {
    const resolvedAt: string = new Date(nowMillis).toISOString()
    let changed: boolean = false
    this.requests.forEach((request: ConfirmationRequest, index: number) => {
      if (request.status === ConfirmationRequestStatus.PENDING &&
        Date.parse(request.expiresAt) <= nowMillis) {
        const transition: ConfirmationTransitionResult =
          transitionConfirmationRequest(
            request,
            ConfirmationRequestStatus.TIMEOUT,
            resolvedAt
          )
        if (transition.accepted) {
          this.requests[index] = transition.request
          changed = true
        }
      }
    })
    if (changed) {
      this.requests = this.requests.slice()
      await this.persist()
      this.notifyPendingListener()
    }
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
      adminConfirmRequired: false,
      status: ConfirmationRequestStatus.PENDING,
      createdAt: now.toISOString(),
      expiresAt: new Date(now.getTime() + 300000).toISOString(),
      resolvedAt: ''
    }
    this.requests.push(request)
    this.requests = this.requests.slice()
    this.notifyPendingListener()
    return cloneConfirmationRequest(request)
  }

  currentOrCreateLegacyMock(
    digitalCardId: string,
    permissionId: string,
    randomCode: string
  ): ConfirmationRequest {
    const active: ConfirmationRequest | null = this.activePendingRequest()
    if (active) {
      return active
    }
    return this.receiveLocalMockRequest(digitalCardId, permissionId, randomCode)
  }

  approveLocalMock(requestId: string): ConfirmationTransitionResult | null {
    return this.resolveLocalMock(requestId, ConfirmationRequestStatus.APPROVED)
  }

  hasAuthoritativeLocalResult(requestId: string): boolean {
    const request: ConfirmationRequest | null = this.getRequest(requestId)
    return request !== null &&
      request.status === ConfirmationRequestStatus.APPROVED &&
      this.lastOperation.operationId === `confirmation-${requestId}` &&
      isAuthoritativeSuccess(this.lastOperation)
  }

  hasAuthoritativeBackendResult(requestId: string): boolean {
    const request: ConfirmationRequest | null = this.getRequest(requestId)
    return request !== null &&
      isTerminalConfirmationStatus(request.status) &&
      this.lastOperation.operationId === `confirmation-${requestId}` &&
      this.lastOperation.authority === OperationAuthority.BACKEND &&
      isAuthoritativeSuccess(this.lastOperation)
  }

  getRequest(requestId: string): ConfirmationRequest | null {
    const index: number = this.findRequestIndex(requestId)
    return index >= 0 ? cloneConfirmationRequest(this.requests[index]) : null
  }

  private resolveLocalMock(
    requestId: string,
    status: ConfirmationRequestStatus
  ): ConfirmationTransitionResult | null {
    const index: number = this.findRequestIndex(requestId)
    if (index < 0) {
      return null
    }
    const resolvedAt: string = new Date().toISOString()
    const transition: ConfirmationTransitionResult =
      transitionConfirmationRequest(this.requests[index], status, resolvedAt)
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
    this.notifyPendingListener()
    return transition
  }

  private failedOperation(
    requestId: string,
    errorCode: string,
    updatedAt: string
  ): OperationReceipt {
    return {
      operationId: `confirmation-${requestId}`,
      state: OperationState.FAILED,
      authority: OperationAuthority.BACKEND,
      verificationRequired: false,
      receiptId: '',
      errorCode: errorCode,
      updatedAt: updatedAt
    }
  }

  private async persist(): Promise<void> {
    if (!this.persistenceService) {
      return
    }
    await this.persistenceService.save({
      schemaVersion: CONFIRMATION_SCHEMA_VERSION,
      requests: this.requests,
      lastOperation: this.lastOperation
    })
  }

  private notifyPendingListener(): void {
    if (this.pendingListener) {
      this.pendingListener(this.activePendingRequest())
    }
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
