import { describe, expect, it } from '@ohos/hypium'
import { ConfirmationDecisionResult } from '../main/ets/models/ConfirmationOperation'
import {
  cloneConfirmationRequest,
  ConfirmationDirection,
  ConfirmationRequest,
  ConfirmationRequestStatus
} from '../main/ets/models/ConfirmationRequest'
import {
  MobileWebSocketEnvelope,
  MobileWebSocketMessageType,
  MobileWebSocketRouteResult
} from '../main/ets/models/MobileWebSocketMessage'
import { OperationAuthority, OperationState } from '../main/ets/models/Operation'
import { ConfirmationBackendService } from '../main/ets/services/ConfirmationBackendService'
import { InMemoryConfirmationPersistence } from '../main/ets/services/InMemoryConfirmationPersistence'
import { MobileWebSocketRouter } from '../main/ets/services/MobileWebSocketRouter'
import { ConfirmationStore } from '../main/ets/stores/ConfirmationStore'

class TestConfirmationBackend implements ConfirmationBackendService {
  pending: ConfirmationRequest[] = []
  decisionCalls: number = 0
  failDecision: boolean = false

  async listPendingConfirmations(): Promise<ConfirmationRequest[]> {
    return this.pending.map((request: ConfirmationRequest) =>
      cloneConfirmationRequest(request))
  }

  async decideConfirmation(
    requestId: string,
    status: ConfirmationRequestStatus
  ): Promise<ConfirmationDecisionResult> {
    this.decisionCalls++
    if (this.failDecision) {
      throw new Error('Backend decision failure')
    }
    const request: ConfirmationRequest = cloneConfirmationRequest(this.pending[0])
    request.status = status
    request.resolvedAt = '2026-08-14T02:01:00.000Z'
    return {
      request: request,
      operation: {
        operationId: `confirmation-${requestId}`,
        state: OperationState.ACKNOWLEDGED,
        authority: OperationAuthority.BACKEND,
        verificationRequired: false,
        receiptId: `backend-${requestId}`,
        errorCode: '',
        updatedAt: request.resolvedAt
      }
    }
  }
}

function confirmationRequest(
  requestId: string,
  expiresAt: string,
  adminConfirmRequired: boolean = true
): ConfirmationRequest {
  return {
    requestId: requestId,
    digitalCardId: '1',
    permissionId: 'authorization-identity',
    detectorId: 'detector-b-1',
    checkpointName: 'North gate',
    eventId: `event-${requestId}`,
    action: 'access',
    direction: ConfirmationDirection.ENTRY,
    randomCode: '123456',
    adminConfirmRequired: adminConfirmRequired,
    status: ConfirmationRequestStatus.PENDING,
    createdAt: '2026-08-14T02:00:00.000Z',
    expiresAt: expiresAt,
    resolvedAt: ''
  }
}

function webSocketEnvelope(
  subjectId: string,
  request: ConfirmationRequest
): string {
  const envelope: MobileWebSocketEnvelope = {
    type: MobileWebSocketMessageType.CONFIRMATION_REQUEST,
    subjectId: subjectId,
    confirmation: request,
    cardId: '',
    serverRevision: ''
  }
  return JSON.stringify(envelope)
}

export default function confirmationFlowTest() {
  describe('SLE-ID production confirmation flow', () => {
    it('merges a duplicate WebSocket request idempotently', 0, async () => {
      const store: ConfirmationStore = new ConfirmationStore(
        null,
        new InMemoryConfirmationPersistence()
      )
      const router: MobileWebSocketRouter = new MobileWebSocketRouter(
        'subject-1',
        async (request: ConfirmationRequest) => {
          await store.receiveProductionRequest(request)
        },
        async (cardId: string, serverRevision: string) => {}
      )
      const message: string = webSocketEnvelope(
        'subject-1',
        confirmationRequest('request-ws-1', '2099-01-01T00:00:00.000Z')
      )
      await router.route(message)
      await router.route(message)
      expect(store.requests.length).assertEqual(1)
    })

    it('does not approve an expired production request', 0, async () => {
      const backend: TestConfirmationBackend = new TestConfirmationBackend()
      const expired: ConfirmationRequest = confirmationRequest(
        'request-expired-1',
        '2000-01-01T00:00:00.000Z'
      )
      backend.pending = [expired]
      const store: ConfirmationStore = new ConfirmationStore(
        backend,
        new InMemoryConfirmationPersistence()
      )
      await store.receiveProductionRequest(expired)
      const approved: boolean = await store.submitDecision(
        expired.requestId,
        ConfirmationRequestStatus.APPROVED
      )
      expect(approved).assertFalse()
      expect(store.getRequest(expired.requestId)?.status).assertEqual(
        ConfirmationRequestStatus.TIMEOUT
      )
      expect(backend.decisionCalls).assertEqual(0)
    })

    it('does not duplicate pending requests after reconnect recovery', 0, async () => {
      const backend: TestConfirmationBackend = new TestConfirmationBackend()
      backend.pending = [confirmationRequest(
        'request-recovery-1',
        '2099-01-01T00:00:00.000Z'
      )]
      const store: ConfirmationStore = new ConfirmationStore(
        backend,
        new InMemoryConfirmationPersistence()
      )
      await store.recoverPending()
      await store.recoverPending()
      expect(store.requests.length).assertEqual(1)
    })

    it('keeps a request pending when backend decision fails', 0, async () => {
      const backend: TestConfirmationBackend = new TestConfirmationBackend()
      const request: ConfirmationRequest = confirmationRequest(
        'request-failure-1',
        '2099-01-01T00:00:00.000Z'
      )
      backend.pending = [request]
      backend.failDecision = true
      const store: ConfirmationStore = new ConfirmationStore(
        backend,
        new InMemoryConfirmationPersistence()
      )
      await store.receiveProductionRequest(request)
      const approved: boolean = await store.submitDecision(
        request.requestId,
        ConfirmationRequestStatus.APPROVED
      )
      expect(approved).assertFalse()
      expect(store.getRequest(request.requestId)?.status).assertEqual(
        ConfirmationRequestStatus.PENDING
      )
      expect(store.lastOperation.state).assertEqual(OperationState.FAILED)
    })

    it('preserves administrator-required confirmation on mapping', 0, async () => {
      const store: ConfirmationStore = new ConfirmationStore(
        null,
        new InMemoryConfirmationPersistence()
      )
      const request: ConfirmationRequest = confirmationRequest(
        'request-admin-1',
        '2099-01-01T00:00:00.000Z',
        true
      )
      await store.receiveProductionRequest(request)
      expect(store.getRequest(request.requestId)?.adminConfirmRequired).assertTrue()
    })

    it('rejects a WebSocket message for another authenticated subject', 0, async () => {
      let received: number = 0
      const router: MobileWebSocketRouter = new MobileWebSocketRouter(
        'subject-owner',
        async (request: ConfirmationRequest) => {
          received++
        },
        async (cardId: string, serverRevision: string) => {}
      )
      const result: MobileWebSocketRouteResult = await router.route(
        webSocketEnvelope(
          'subject-other',
          confirmationRequest('request-other-1', '2099-01-01T00:00:00.000Z')
        )
      )
      expect(result).assertEqual(MobileWebSocketRouteResult.SUBJECT_MISMATCH)
      expect(received).assertEqual(0)
    })
  })
}
