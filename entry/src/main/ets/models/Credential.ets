import { AuthorizationAlertLevel } from './Authorization'

export enum CredentialBindingStatus {
  NOT_WRITTEN = 'notWritten',
  DISCOVERING = 'discovering',
  CONNECTING = 'connecting',
  WRITING = 'writing',
  VERIFYING = 'verifying',
  WRITTEN = 'written',
  UPDATE_REQUIRED = 'updateRequired',
  WRITE_FAILED = 'writeFailed',
  REMOVED = 'removed'
}

export interface CredentialPolicyFlags {
  recordEvent: boolean
  allowExecution: boolean
  adminConfirmationRequired: boolean
  alertOnUnauthorized: boolean
  alertLevel: AuthorizationAlertLevel
  offlineAllowed: boolean
  phoneSubstituteAllowed: boolean
  directionDetection: boolean
}

export interface Credential {
  credentialId: string
  authorizationId: string
  issuerId: string
  physicalCardId: string
  protocolVersion: string
  credentialVersion: number
  permissionScopeDigest: string
  policyFlags: CredentialPolicyFlags
  validFrom: string
  validUntil: string
  keyVersion: number
  mockAuthenticationMaterial: string
  integrityCheck: string
  bindingStatus: CredentialBindingStatus
  writtenAt: string
  verifiedAt: string
}
