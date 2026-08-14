import {
  OrganizationId,
  PermissionId,
  PolicyVersion
} from './DomainIdentifiers'
import { SyncState } from './SyncState'

export enum AuthorizationStatus {
  DRAFT = 'draft',
  INVITED = 'invited',
  BOUND = 'bound',
  ACTIVE = 'active',
  EXPIRED = 'expired',
  REVOKED = 'revoked',
  USAGE_EXHAUSTED = 'usageExhausted'
}

export enum AuthorizationUsageMode {
  UNLIMITED = 'unlimited',
  LIMITED = 'limited'
}

export enum AuthorizationAlertPolicy {
  DEFAULT = 'default',
  NOTIFY_ON_USE = 'notify_on_use',
  HIGH_ATTENTION = 'high_attention'
}

export enum AuthorizationAlertLevel {
  NONE = 'none',
  INFO = 'info',
  WARNING = 'warning',
  CRITICAL = 'critical'
}

export interface Authorization {
  permissionId: PermissionId
  digitalCardId: string
  organizationId: OrganizationId
  name: string
  issuer: string
  status: AuthorizationStatus
  scopes: string[]
  validFrom: string
  validUntil: string
  usageMode: AuthorizationUsageMode
  usageLimit: number
  remainingUses: number
  readonly adminConfirmRequired: boolean
  phoneSubstituteAllowed: boolean
  alertPolicy: AuthorizationAlertPolicy
  recordEvent: boolean
  allowExecution: boolean
  alertOnUnauthorized: boolean
  alertLevel: AuthorizationAlertLevel
  offlineAllowed: boolean
  directionDetection: boolean
  policyVersion: PolicyVersion
  syncState: SyncState
}
