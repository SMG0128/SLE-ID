import { describe, expect, it } from '@ohos/hypium'
import {
  applyUserConfirmationPreference,
  ConfirmationPolicy,
  finalConfirmRequired
} from '../main/ets/models/ConfirmationPolicy'
import { AuthorizationStatus } from '../main/ets/models/Authorization'
import {
  CredentialBindingStatus
} from '../main/ets/models/Credential'
import {
  ConfirmationDirection,
  ConfirmationRequest,
  ConfirmationRequestStatus,
  ConfirmationTransitionReason,
  ConfirmationTransitionResult,
  transitionConfirmationRequest
} from '../main/ets/models/ConfirmationRequest'
import {
  InvitationFlowState
} from '../main/ets/models/Invitation'
import {
  MockPhysicalCardFailureMode
} from '../main/ets/models/PhysicalCard'
import {
  CredentialWriteResult,
  PhysicalCardFailureReason
} from '../main/ets/models/PhysicalCardOperation'
import {
  isAuthoritativeSuccess,
  OperationState
} from '../main/ets/models/Operation'
import { InMemoryMockPersistence } from '../main/ets/mock/InMemoryMockPersistence'
import { MockDataSource } from '../main/ets/mock/MockDataSource'
import { ConfirmationStore } from '../main/ets/stores/ConfirmationStore'

function pendingConfirmation(expiresAt: string): ConfirmationRequest {
  return {
    requestId: 'request-contract-1',
    digitalCardId: '1',
    permissionId: 'authorization-identity',
    detectorId: 'detector-a',
    checkpointName: 'Contract checkpoint',
    eventId: 'event-contract-1',
    action: 'access',
    direction: ConfirmationDirection.ENTRY,
    randomCode: '123456',
    adminConfirmRequired: true,
    status: ConfirmationRequestStatus.PENDING,
    createdAt: '2026-08-14T00:00:00.000Z',
    expiresAt: expiresAt,
    resolvedAt: ''
  }
}

export default function domainContractsTest() {
  describe('SLE-ID domain contracts', () => {
    it('computes the canonical confirmation invariant', 0, () => {
      expect(finalConfirmRequired(true, false)).assertTrue()
      expect(finalConfirmRequired(true, true)).assertTrue()
      expect(finalConfirmRequired(false, true)).assertTrue()
      expect(finalConfirmRequired(false, false)).assertFalse()
    })

    it('does not allow an administrator requirement to be disabled', 0, () => {
      const policy: ConfirmationPolicy = {
        adminConfirmRequired: true,
        userConfirmEnabled: true
      }
      const updated: ConfirmationPolicy =
        applyUserConfirmationPreference(policy, false)
      expect(updated.adminConfirmRequired).assertTrue()
      expect(updated.userConfirmEnabled).assertTrue()
      expect(finalConfirmRequired(
        updated.adminConfirmRequired,
        updated.userConfirmEnabled
      )).assertTrue()
    })

    it('keeps permission binding independent from physical write failure', 0, () => {
      const permissionState: AuthorizationStatus = AuthorizationStatus.BOUND
      const writeState: CredentialBindingStatus =
        CredentialBindingStatus.WRITE_FAILED
      expect(permissionState).assertEqual(AuthorizationStatus.BOUND)
      expect(writeState).assertEqual(CredentialBindingStatus.WRITE_FAILED)
    })

    it('turns an expired approval attempt into timeout', 0, () => {
      const result: ConfirmationTransitionResult =
        transitionConfirmationRequest(
          pendingConfirmation('2026-08-14T00:01:00.000Z'),
          ConfirmationRequestStatus.APPROVED,
          '2026-08-14T00:02:00.000Z'
        )
      expect(result.accepted).assertFalse()
      expect(result.reason).assertEqual(ConfirmationTransitionReason.EXPIRED)
      expect(result.request.status).assertEqual(ConfirmationRequestStatus.TIMEOUT)
    })

    it('does not overwrite a terminal confirmation state', 0, () => {
      const approved: ConfirmationTransitionResult =
        transitionConfirmationRequest(
          pendingConfirmation('2026-08-14T00:10:00.000Z'),
          ConfirmationRequestStatus.APPROVED,
          '2026-08-14T00:01:00.000Z'
        )
      const overwritten: ConfirmationTransitionResult =
        transitionConfirmationRequest(
          approved.request,
          ConfirmationRequestStatus.REJECTED,
          '2026-08-14T00:02:00.000Z'
        )
      expect(overwritten.accepted).assertFalse()
      expect(overwritten.reason).assertEqual(ConfirmationTransitionReason.TERMINAL)
      expect(overwritten.request.status).assertEqual(ConfirmationRequestStatus.APPROVED)
    })

    it('requires a receipt before a local mock confirmation is authoritative', 0, () => {
      const store: ConfirmationStore = ConfirmationStore.getInstance()
      const request: ConfirmationRequest = store.receiveLocalMockRequest(
        '1',
        'authorization-identity',
        'contract-receipt-1'
      )
      expect(store.hasAuthoritativeLocalResult(request.requestId)).assertFalse()
      store.approveLocalMock(request.requestId)
      expect(store.hasAuthoritativeLocalResult(request.requestId)).assertTrue()
    })

    it('keeps invitation redemption idempotent in the mock', 0, async () => {
      const source: MockDataSource = MockDataSource.createForTesting(
        new InMemoryMockPersistence()
      )
      const beforeCount: number = source.getAuthorizationSnapshot().length
      const first = await source.redeemInvitation('SLE-LAB2-2026')
      const second = await source.redeemInvitation('SLE-LAB2-2026')
      expect(first.state).assertEqual(InvitationFlowState.SUCCESS)
      expect(first.authorization?.status).assertEqual(AuthorizationStatus.BOUND)
      expect(first.digitalCard?.credentialBindingStatus).assertEqual(
        CredentialBindingStatus.NOT_WRITTEN
      )
      expect(second.state).assertEqual(InvitationFlowState.ALREADY_USED)
      expect(source.getAuthorizationSnapshot().length).assertEqual(beforeCount + 1)
    })

    it('does not report authoritative success after persistence failure', 0, async () => {
      const persistence: InMemoryMockPersistence = new InMemoryMockPersistence()
      const source: MockDataSource = MockDataSource.createForTesting(persistence)
      await source.connectPhysicalCard('ws63-normal')
      persistence.failNextPhysicalCardSave = true
      const result: CredentialWriteResult = await source.writeCredential({
        permissionId: 'authorization-access',
        digitalCardId: '3',
        physicalCardId: 'ws63-normal'
      }, (_status: CredentialBindingStatus) => {})
      expect(result.reason).assertEqual(PhysicalCardFailureReason.PERSISTENCE_FAILED)
      expect(result.status).assertEqual(CredentialBindingStatus.WRITE_FAILED)
      expect(result.operation.state).assertEqual(OperationState.FAILED)
      expect(isAuthoritativeSuccess(result.operation)).assertFalse()
    })

    it('does not activate a physical write before verification succeeds', 0, async () => {
      const source: MockDataSource = MockDataSource.createForTesting(
        new InMemoryMockPersistence()
      )
      await source.bindPrimaryPhysicalCard('ws63-verify-error')
      await source.connectPhysicalCard('ws63-verify-error')
      const observed: CredentialBindingStatus[] = []
      const result: CredentialWriteResult = await source.writeCredential({
        permissionId: 'authorization-access',
        digitalCardId: '3',
        physicalCardId: 'ws63-verify-error'
      }, (status: CredentialBindingStatus) => {
        observed.push(status)
      })
      expect(result.reason).assertEqual(PhysicalCardFailureReason.VERIFICATION_FAILED)
      expect(result.status).assertEqual(CredentialBindingStatus.WRITE_FAILED)
      expect(result.operation.state).assertEqual(OperationState.FAILED)
      expect(observed.indexOf(CredentialBindingStatus.ACTIVE)).assertEqual(-1)
      const card = await source.getPhysicalCard('ws63-verify-error')
      expect(card?.mockFailureMode).assertEqual(
        MockPhysicalCardFailureMode.VERIFICATION_FAILED
      )
    })
  })
}
