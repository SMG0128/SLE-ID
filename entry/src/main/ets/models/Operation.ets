export enum OperationState {
  IDLE = 'idle',
  PENDING = 'pending',
  ACKNOWLEDGED = 'acknowledged',
  VERIFIED = 'verified',
  FAILED = 'failed'
}

export enum OperationAuthority {
  NONE = 'none',
  LOCAL = 'local',
  BACKEND = 'backend',
  PHYSICAL_CARD = 'physicalCard'
}

export interface OperationReceipt {
  operationId: string
  state: OperationState
  authority: OperationAuthority
  verificationRequired: boolean
  receiptId: string
  errorCode: string
  updatedAt: string
}

export function createPendingOperation(
  operationId: string,
  authority: OperationAuthority,
  verificationRequired: boolean,
  updatedAt: string
): OperationReceipt {
  return {
    operationId: operationId,
    state: OperationState.PENDING,
    authority: authority,
    verificationRequired: verificationRequired,
    receiptId: '',
    errorCode: '',
    updatedAt: updatedAt
  }
}

export function isAuthoritativeSuccess(receipt: OperationReceipt): boolean {
  if (receipt.verificationRequired) {
    return receipt.state === OperationState.VERIFIED &&
      receipt.receiptId.length > 0
  }
  return receipt.state === OperationState.ACKNOWLEDGED &&
    receipt.receiptId.length > 0
}

