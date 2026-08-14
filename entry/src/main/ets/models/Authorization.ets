export enum AuthorizationStatus {
  PENDING = 'pending',
  ACTIVE = 'active',
  FROZEN = 'frozen',
  EXPIRED = 'expired',
  REVOKED = 'revoked',
  LOST = 'lost',
  CANCELLED = 'cancelled'
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
  id: string
  digitalCardId: string
  issuerId: string
  name: string
  issuer: string
  status: AuthorizationStatus
  scopes: string[]
  validFrom: string
  validUntil: string
  usageMode: AuthorizationUsageMode
  usageLimit: number
  remainingUses: number
  adminConfirmationRequired: boolean
  phoneSubstituteAllowed: boolean
  alertPolicy: AuthorizationAlertPolicy
  recordEvent: boolean
  allowExecution: boolean
  alertOnUnauthorized: boolean
  alertLevel: AuthorizationAlertLevel
  offlineAllowed: boolean
  directionDetection: boolean
  lastSyncedAt: string
}
