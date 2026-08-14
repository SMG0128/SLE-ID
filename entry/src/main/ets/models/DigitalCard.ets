import {
  CredentialBindingStatus,
  CredentialCondition
} from './Credential'
import { CardAnonId, PermissionId } from './DomainIdentifiers'
import { SyncState } from './SyncState'

export enum DigitalCardStatus {
  UNACTIVATED = 'unactivated',
  ACTIVE = 'active',
  FROZEN = 'frozen',
  LOST = 'lost',
  EXPIRED = 'expired',
  REVOKED = 'revoked',
  DEREGISTERED = 'deregistered',
  PENDING_SYNC = 'pending_sync'
}

export enum DigitalCardVisualStyle {
  IDENTITY = 'identity',
  TRANSIT = 'transit',
  ACCESS = 'access'
}

export interface DigitalCard {
  id: string
  name: string
  issuer: string
  cardAnonId: CardAnonId
  anonymousNumber: string
  nickname: string
  detail: string
  category: string
  status: DigitalCardStatus
  visualStyle: DigitalCardVisualStyle
  permissionId: PermissionId
  credentialId: string
  physicalCardId: string
  credentialBindingStatus: CredentialBindingStatus
  credentialCondition: CredentialCondition
  readonly adminConfirmRequired: boolean
  userConfirmationEnabled: boolean
  allowTemporaryPass: boolean
  validFrom: string
  validUntil: string
  syncState: SyncState
}
