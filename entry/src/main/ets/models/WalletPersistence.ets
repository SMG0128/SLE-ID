import { Authorization } from './Authorization'
import {
  CredentialBindingStatus,
  CredentialCondition
} from './Credential'
import { DigitalCard } from './DigitalCard'
import { PendingMobileMutation } from './MobileOperation'
import { SyncState, createLocalSyncState } from './SyncState'

export const WALLET_SCHEMA_VERSION: number = 1

export interface PersistedCredentialState {
  credentialId: string
  permissionId: string
  physicalCardId: string
  bindingStatus: CredentialBindingStatus
  condition: CredentialCondition
  writtenAt: string
  verifiedAt: string
}

export interface WalletPersistenceState {
  schemaVersion: number
  cards: DigitalCard[]
  authorizations: Authorization[]
  credentialStates: PersistedCredentialState[]
  syncState: SyncState
  pendingMutations: PendingMobileMutation[]
}

export function emptyWalletPersistenceState(): WalletPersistenceState {
  return {
    schemaVersion: WALLET_SCHEMA_VERSION,
    cards: [],
    authorizations: [],
    credentialStates: [],
    syncState: createLocalSyncState(''),
    pendingMutations: []
  }
}

export function serializeWalletState(state: WalletPersistenceState): string {
  return JSON.stringify(state)
}

export function deserializeWalletState(serialized: string): WalletPersistenceState {
  if (serialized.length === 0) {
    return emptyWalletPersistenceState()
  }
  try {
    const parsed: WalletPersistenceState =
      JSON.parse(serialized) as WalletPersistenceState
    if (parsed.schemaVersion !== WALLET_SCHEMA_VERSION ||
      !Array.isArray(parsed.cards) ||
      !Array.isArray(parsed.authorizations) ||
      !Array.isArray(parsed.credentialStates) ||
      !Array.isArray(parsed.pendingMutations) ||
      !parsed.syncState) {
      return emptyWalletPersistenceState()
    }
    return parsed
  } catch (error) {
    return emptyWalletPersistenceState()
  }
}
