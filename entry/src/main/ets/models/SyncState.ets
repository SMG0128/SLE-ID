import { OperationAuthority, OperationState } from './Operation'

export interface PendingOperation {
  operationId: string
  operationType: string
  state: OperationState
  authority: OperationAuthority
  createdAt: string
  lastAttemptAt: string
  attemptCount: number
  payloadReference: string
}

export interface SyncState {
  serverRevision: string
  lastSyncAt: string
  pendingOperations: PendingOperation[]
}

export function createLocalSyncState(lastSyncAt: string): SyncState {
  return {
    serverRevision: '',
    lastSyncAt: lastSyncAt,
    pendingOperations: []
  }
}

