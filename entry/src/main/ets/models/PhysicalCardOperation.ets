import { Credential, CredentialBindingStatus } from './Credential'
import {
  PhysicalCard,
  PhysicalCardConnectionState,
  PhysicalCardDiscoveryState
} from './PhysicalCard'
import { DigitalCard } from './DigitalCard'
import { OperationReceipt } from './Operation'
import { PermissionId } from './DomainIdentifiers'

export enum PhysicalCardFailureReason {
  NONE = 'none',
  NO_DEVICE = 'noDevice',
  DISCOVERY_FAILED = 'discoveryFailed',
  CONNECTION_FAILED = 'connectionFailed',
  CONNECTION_INTERRUPTED = 'connectionInterrupted',
  CAPACITY_FULL = 'capacityFull',
  ALREADY_WRITTEN = 'alreadyWritten',
  TRANSLATION_FAILED = 'translationFailed',
  WRITE_FAILED = 'writeFailed',
  VERIFICATION_FAILED = 'verificationFailed',
  PERSISTENCE_FAILED = 'persistenceFailed',
  DEVICE_OFFLINE = 'deviceOffline',
  CANCELLED = 'cancelled',
  NOT_CONNECTED = 'notConnected',
  NOT_FOUND = 'notFound',
  REMOVE_FAILED = 'removeFailed'
}

export interface PhysicalCardDiscoveryUpdate {
  state: PhysicalCardDiscoveryState
  cards: PhysicalCard[]
}

export interface PhysicalCardConnectionResult {
  state: PhysicalCardConnectionState
  reason: PhysicalCardFailureReason
  card: PhysicalCard | null
}

export interface PrimaryPhysicalCardBindingResult {
  success: boolean
  reason: PhysicalCardFailureReason
  card: PhysicalCard | null
}

export interface CredentialWriteRequest {
  permissionId: PermissionId
  digitalCardId: string
  physicalCardId: string
}

export interface CredentialWriteResult {
  status: CredentialBindingStatus
  reason: PhysicalCardFailureReason
  operation: OperationReceipt
  credential: Credential | null
  physicalCard: PhysicalCard | null
  digitalCard: DigitalCard | null
}

export interface CredentialRemovalResult {
  success: boolean
  reason: PhysicalCardFailureReason
  operation: OperationReceipt
  credentialId: string
  physicalCard: PhysicalCard | null
  digitalCard: DigitalCard | null
}

export type PhysicalCardDiscoveryListener =
  (update: PhysicalCardDiscoveryUpdate) => void

export type CredentialWriteProgressListener =
  (status: CredentialBindingStatus) => void
