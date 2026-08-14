import { DigitalCard, DigitalCardVisualStyle } from './DigitalCard'
import {
  Authorization,
  AuthorizationAlertLevel,
  AuthorizationAlertPolicy,
  AuthorizationUsageMode
} from './Authorization'

export enum InvitationFlowState {
  IDLE = 'idle',
  VALIDATING = 'validating',
  PREVIEW_READY = 'previewReady',
  REDEEMING = 'redeeming',
  SUCCESS = 'success',
  INVALID = 'invalid',
  EXPIRED = 'expired',
  ALREADY_USED = 'alreadyUsed',
  ALREADY_BOUND = 'alreadyBound',
  REQUEST_ERROR = 'requestError'
}

export enum InvitationMockStatus {
  AVAILABLE = 'available',
  EXPIRED = 'expired',
  USED = 'used',
  REQUEST_ERROR = 'requestError'
}

export enum InvitationFailureReason {
  NONE = 'none',
  EMPTY = 'empty',
  FORMAT = 'format',
  NOT_FOUND = 'notFound',
  EXPIRED = 'expired',
  ALREADY_USED = 'alreadyUsed',
  ALREADY_BOUND = 'alreadyBound',
  REQUEST_ERROR = 'requestError'
}

export interface InvitationAuthorizationPreview {
  authorizationId: string
  issuerId: string
  issuerName: string
  cardName: string
  cardDescription: string
  permissionScope: string[]
  validFrom: string
  validUntil: string
  usageMode: AuthorizationUsageMode
  usageLimit: number
  adminConfirmationRequired: boolean
  phoneSubstituteAllowed: boolean
  alertPolicy: AuthorizationAlertPolicy
  recordEvent: boolean
  allowExecution: boolean
  alertOnUnauthorized: boolean
  alertLevel: AuthorizationAlertLevel
  offlineAllowed: boolean
  directionDetection: boolean
  cardAppearance: DigitalCardVisualStyle
  category: string
}

export interface MockInvitation {
  code: string
  status: InvitationMockStatus
  preview: InvitationAuthorizationPreview
}

export interface InvitationPreviewResult {
  state: InvitationFlowState
  reason: InvitationFailureReason
  preview: InvitationAuthorizationPreview | null
}

export interface InvitationRedemptionResult {
  state: InvitationFlowState
  reason: InvitationFailureReason
  preview: InvitationAuthorizationPreview | null
  authorization: Authorization | null
  digitalCard: DigitalCard | null
}
