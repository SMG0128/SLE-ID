import { ConfirmationRequest } from './ConfirmationRequest'
import { OperationAuthority, OperationReceipt, OperationState } from './Operation'

export const CONFIRMATION_SCHEMA_VERSION: number = 1

export interface ConfirmationPersistenceState {
  schemaVersion: number
  requests: ConfirmationRequest[]
  lastOperation: OperationReceipt
}

export function emptyConfirmationPersistenceState(): ConfirmationPersistenceState {
  return {
    schemaVersion: CONFIRMATION_SCHEMA_VERSION,
    requests: [],
    lastOperation: {
      operationId: '',
      state: OperationState.IDLE,
      authority: OperationAuthority.NONE,
      verificationRequired: false,
      receiptId: '',
      errorCode: '',
      updatedAt: ''
    }
  }
}

export function serializeConfirmationState(
  state: ConfirmationPersistenceState
): string {
  return JSON.stringify(state)
}

export function deserializeConfirmationState(
  serialized: string
): ConfirmationPersistenceState {
  if (serialized.length === 0) {
    return emptyConfirmationPersistenceState()
  }
  try {
    const parsed: ConfirmationPersistenceState =
      JSON.parse(serialized) as ConfirmationPersistenceState
    if (parsed.schemaVersion !== CONFIRMATION_SCHEMA_VERSION ||
      !Array.isArray(parsed.requests) || !parsed.lastOperation) {
      return emptyConfirmationPersistenceState()
    }
    return parsed
  } catch (error) {
    return emptyConfirmationPersistenceState()
  }
}
