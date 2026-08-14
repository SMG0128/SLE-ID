import { CredentialBindingStatus } from './Credential'

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
  anonymousNumber: string
  nickname: string
  detail: string
  category: string
  status: DigitalCardStatus
  visualStyle: DigitalCardVisualStyle
  authorizationId: string
  credentialId: string
  physicalCardId: string
  credentialBindingStatus: CredentialBindingStatus
  adminConfirmationRequired: boolean
  userConfirmationEnabled: boolean
  allowTemporaryPass: boolean
  validFrom: string
  validUntil: string
  lastSyncedAt: string
}
