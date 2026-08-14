import { describe, expect, it } from '@ohos/hypium'
import { CredentialBindingStatus, CredentialCondition } from '../main/ets/models/Credential'
import { DigitalCard } from '../main/ets/models/DigitalCard'
import {
  CardPreferenceUpdate,
  MobileCardAction,
  PendingMobileMutation,
  PendingMobileMutationKind
} from '../main/ets/models/MobileOperation'
import { OperationAuthority, OperationState } from '../main/ets/models/Operation'
import {
  emptyWalletPersistenceState,
  WALLET_SCHEMA_VERSION,
  WalletPersistenceState
} from '../main/ets/models/WalletPersistence'
import { InMemoryTokenStore } from '../main/ets/security/TokenStore'
import { InMemoryMockPersistence } from '../main/ets/mock/InMemoryMockPersistence'
import { MockDataSource } from '../main/ets/mock/MockDataSource'
import { InMemoryWalletPersistence } from '../main/ets/services/InMemoryWalletPersistence'
import { MobileApiClient } from '../main/ets/services/MobileApiClient'
import {
  MobileHttpRequest,
  MobileHttpResponse,
  MobileHttpTransport
} from '../main/ets/services/MobileApiContracts'
import {
  createCardPreferenceBody,
  preserveAdminConfirmationRequirement
} from '../main/ets/services/MobileApiClient'
import { SessionStore } from '../main/ets/stores/SessionStore'

class FailingMobileTransport implements MobileHttpTransport {
  async send(request: MobileHttpRequest): Promise<MobileHttpResponse> {
    return {
      statusCode: 503,
      body: JSON.stringify({ error: 'unavailable' })
    }
  }
}

function pendingMutation(): PendingMobileMutation {
  return {
    operationId: 'pending-preference-1',
    kind: PendingMobileMutationKind.PREFERENCES,
    cardId: 'card-1',
    preferenceUpdate: { userConfirmEnabled: true },
    action: null,
    createdAt: '2026-08-14T01:00:00.000Z',
    lastAttemptAt: '',
    attemptCount: 0,
    state: OperationState.PENDING
  }
}

export default function mobileCoreTest() {
  describe('SLE-ID mobile core', () => {
    it('restores persisted wallet metadata and credential state after restart', 0, async () => {
      const persistence: InMemoryWalletPersistence = new InMemoryWalletPersistence()
      const state: WalletPersistenceState = emptyWalletPersistenceState()
      state.credentialStates.push({
        credentialId: 'credential-1',
        permissionId: 'permission-1',
        physicalCardId: 'card-c-1',
        bindingStatus: CredentialBindingStatus.WRITE_FAILED,
        condition: CredentialCondition.ACTIVE,
        writtenAt: '',
        verifiedAt: ''
      })
      state.syncState.serverRevision = 'revision-7'
      state.syncState.lastSyncAt = '2026-08-14T01:02:00.000Z'
      await persistence.save(state)

      const restored: WalletPersistenceState = await persistence.load()
      expect(restored.schemaVersion).assertEqual(WALLET_SCHEMA_VERSION)
      expect(restored.credentialStates.length).assertEqual(1)
      expect(restored.credentialStates[0].bindingStatus).assertEqual(
        CredentialBindingStatus.WRITE_FAILED
      )
      expect(restored.syncState.serverRevision).assertEqual('revision-7')
    })

    it('does not create authoritative success for a backend failure', 0, async () => {
      const sessionStore: SessionStore = new SessionStore(new InMemoryTokenStore())
      await sessionStore.accept({
        accessToken: 'test-access-token',
        refreshToken: '',
        expiresAt: '2099-01-01T00:00:00.000Z'
      })
      const client: MobileApiClient = new MobileApiClient(
        new FailingMobileTransport(),
        sessionStore
      )
      let failed: boolean = false
      try {
        await client.updateCardPreferences('card-1', { nickname: 'New name' })
      } catch (error) {
        failed = true
      }
      expect(failed).assertTrue()
    })

    it('never sends administrator confirmation policy as a user preference', 0, () => {
      const update: CardPreferenceUpdate = { userConfirmEnabled: false }
      const body: string = createCardPreferenceBody(update)
      expect(body.indexOf('adminConfirmRequired')).assertEqual(-1)
      expect(body.indexOf('userConfirmEnabled')).assertLarger(-1)

      const source: MockDataSource = MockDataSource.createForTesting(
        new InMemoryMockPersistence()
      )
      let current: DigitalCard = source.getCardSnapshot()[0]
      source.getCardSnapshot().forEach((card: DigitalCard) => {
        if (card.adminConfirmRequired) {
          current = card
        }
      })
      const weakenedJson: string = JSON.stringify(current).replace(
        '"adminConfirmRequired":true',
        '"adminConfirmRequired":false'
      )
      const weakened: DigitalCard = JSON.parse(weakenedJson) as DigitalCard
      const preserved: DigitalCard = preserveAdminConfirmationRequirement(
        current,
        weakened
      )
      expect(preserved.adminConfirmRequired).assertTrue()
    })

    it('keeps a pending safe operation through a persistence round trip', 0, async () => {
      const persistence: InMemoryWalletPersistence = new InMemoryWalletPersistence()
      const state: WalletPersistenceState = emptyWalletPersistenceState()
      const mutation: PendingMobileMutation = pendingMutation()
      state.pendingMutations.push(mutation)
      state.syncState.pendingOperations.push({
        operationId: mutation.operationId,
        operationType: mutation.kind,
        state: mutation.state,
        authority: OperationAuthority.BACKEND,
        createdAt: mutation.createdAt,
        lastAttemptAt: mutation.lastAttemptAt,
        attemptCount: mutation.attemptCount,
        payloadReference: `${mutation.kind}:${mutation.cardId}`
      })
      await persistence.save(state)

      const restored: WalletPersistenceState = await persistence.load()
      expect(restored.pendingMutations.length).assertEqual(1)
      expect(restored.pendingMutations[0].operationId).assertEqual(
        'pending-preference-1'
      )
      expect(restored.syncState.pendingOperations.length).assertEqual(1)
    })
  })
}
