import { AuthorizationAlertLevel } from './Authorization'
import {
  OrganizationId,
  PermissionId,
  PolicyVersion
} from './DomainIdentifiers'

export enum CredentialBindingStatus {
  NOT_WRITTEN = 'notWritten',
  WRITING = 'writing',
  VERIFYING = 'verifying',
  ACTIVE = 'written',
  // Compatibility alias for existing UI bindings and persisted mock data.
  WRITTEN = 'written',
  WRITE_FAILED = 'writeFailed'
}

export enum CredentialCondition {
  ACTIVE = 'active',
  FROZEN = 'frozen',
  LOST = 'lost',
  EXPIRED = 'expired',
  REVOKED = 'revoked',
  UPDATE_REQUIRED = 'updateRequired',
  REMOVED = 'removed'
}

export interface CredentialPolicyFlags {
  recordEvent: boolean
  allowExecution: boolean
  readonly adminConfirmRequired: boolean
  alertOnUnauthorized: boolean
  alertLevel: AuthorizationAlertLevel
  offlineAllowed: boolean
  phoneSubstituteAllowed: boolean
  directionDetection: boolean
}

export interface Credential {
  credentialId: string
  permissionId: PermissionId
  organizationId: OrganizationId
  physicalCardId: string
  protocolVersion: string
  credentialVersion: number
  policyVersion: PolicyVersion
  permissionScopeDigest: string
  policyFlags: CredentialPolicyFlags
  validFrom: string
  validUntil: string
  keyVersion: number
  mockAuthenticationMaterial: string
  integrityCheck: string
  bindingStatus: CredentialBindingStatus
  condition: CredentialCondition
  writtenAt: string
  verifiedAt: string
}
