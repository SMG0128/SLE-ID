import { ConfirmationRequest } from './ConfirmationRequest'

export enum MobileWebSocketMessageType {
  CONFIRMATION_REQUEST = 'confirmation.request',
  CARD_STATUS = 'card.status',
  CARD_REVOKED = 'card.revoked'
}

export interface MobileWebSocketEnvelope {
  type: MobileWebSocketMessageType
  subjectId: string
  confirmation: ConfirmationRequest | null
  cardId: string
  serverRevision: string
}

export enum MobileWebSocketRouteResult {
  CONFIRMATION = 'confirmation',
  CARD_CHANGE = 'cardChange',
  SUBJECT_MISMATCH = 'subjectMismatch',
  INVALID = 'invalid',
  UNSUPPORTED = 'unsupported'
}
