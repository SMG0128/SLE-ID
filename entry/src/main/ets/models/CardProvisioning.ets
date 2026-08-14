import { CardAnonId, PermissionId } from './DomainIdentifiers'
import { CredentialBindingStatus } from './Credential'
import {
  OperationAuthority,
  OperationReceipt,
  OperationState
} from './Operation'

export const CARD_CREDENTIAL_PAYLOAD_LENGTH: number = 78

export enum CardProvisioningStage {
  IDLE = 'idle',
  SCANNING = 'scanning',
  CONNECTING = 'connecting',
  AUTHENTICATING = 'authenticating',
  WRITING = 'writing',
  VERIFYING = 'verifying',
  SYNCHRONIZING = 'synchronizing',
  SUCCESS = 'success',
  RETRYABLE_FAILURE = 'retryableFailure'
}

export enum CardProvisioningFailure {
  NONE = 'none',
  SCAN_TIMEOUT = 'scanTimeout',
  CONNECTION_FAILED = 'connectionFailed',
  IDENTITY_MISMATCH = 'identityMismatch',
  AUTHENTICATION_FAILED = 'authenticationFailed',
  AUTHORIZATION_EXPIRED = 'authorizationExpired',
  AUTHORIZATION_REPLAYED = 'authorizationReplayed',
  INVALID_WRITE_PACKAGE = 'invalidWritePackage',
  CHUNK_WRITE_FAILED = 'chunkWriteFailed',
  COMMIT_FAILED = 'commitFailed',
  READBACK_MISMATCH = 'readbackMismatch',
  RECEIPT_PERSISTENCE_FAILED = 'receiptPersistenceFailed',
  RECEIPT_UPLOAD_FAILED = 'receiptUploadFailed',
  CONNECTION_INTERRUPTED = 'connectionInterrupted'
}

export interface CardWriteTarget {
  physicalCardId: string
  cardAnonId: CardAnonId
}

// The ticket and nonce are opaque to mobile. They are consumed transiently and
// are deliberately excluded from every persistence contract in this module.
export interface CardWriteAuthorization {
  requestId: string
  nonce: string
  expiresAt: string
  writeTicket: string
}

export interface CardWritePackage {
  requestId: string
  digitalCardId: string
  target: CardWriteTarget
  permissionId: PermissionId
  credentialVersion: number
  credentialPayload: Uint8Array
  credentialHash: string
  expireAt: string
  authorization: CardWriteAuthorization
}

export interface CardCInfo {
  physicalCardId: string
  cardAnonId: CardAnonId
  protocolVersion: string
  maxCredentialChunkBytes: number
}

export interface CardCredentialReadback {
  permissionId: PermissionId
  credentialVersion: number
  generation: string
  credentialHash: string
}

export interface CardCommitAcknowledgement {
  accepted: boolean
  generation: string
}

export interface PendingWriteReceipt {
  operationId: string
  requestId: string
  digitalCardId: string
  physicalCardId: string
  permissionId: PermissionId
  credentialVersion: number
  generation: string
  credentialHash: string
  verifiedAt: string
  createdAt: string
  lastAttemptAt: string
  attemptCount: number
}

export interface WriteReceiptAcknowledgement {
  receiptId: string
  acknowledgedAt: string
}

export interface CardProvisioningResult {
  stage: CardProvisioningStage
  failure: CardProvisioningFailure
  credentialStatus: CredentialBindingStatus
  physicalVerified: boolean
  backendAcknowledged: boolean
  receiptPending: boolean
  requestId: string
  physicalOperation: OperationReceipt
  receiptOperation: OperationReceipt
}

export type CardProvisioningStageListener =
  (stage: CardProvisioningStage) => void

export function createIdleProvisioningResult(): CardProvisioningResult {
  return {
    stage: CardProvisioningStage.IDLE,
    failure: CardProvisioningFailure.NONE,
    credentialStatus: CredentialBindingStatus.NOT_WRITTEN,
    physicalVerified: false,
    backendAcknowledged: false,
    receiptPending: false,
    requestId: '',
    physicalOperation: emptyProvisioningOperation(),
    receiptOperation: emptyProvisioningOperation()
  }
}

export function emptyProvisioningOperation(): OperationReceipt {
  return {
    operationId: '',
    state: OperationState.IDLE,
    authority: OperationAuthority.NONE,
    verificationRequired: false,
    receiptId: '',
    errorCode: '',
    updatedAt: ''
  }
}
