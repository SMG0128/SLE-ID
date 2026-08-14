import { Authorization } from '../models/Authorization'
import { ConfirmationRequest } from '../models/ConfirmationRequest'
import { ConfirmationDecisionResult } from '../models/ConfirmationOperation'
import { DigitalCard } from '../models/DigitalCard'
import {
  InvitationAuthorizationPreview,
  InvitationRedemptionResult
} from '../models/Invitation'
import { MobileSession } from '../models/MobileSession'
import { CardMutationResult } from '../models/MobileOperation'

export interface PairResponse {
  session: MobileSession
}

export interface WalletResponse {
  cards: DigitalCard[]
  authorizations: Authorization[]
  serverRevision: string
}

export interface InvitationPreviewResponse {
  preview: InvitationAuthorizationPreview
}

export interface InvitationRedeemResponse {
  result: InvitationRedemptionResult
}

export interface CardMutationResponse {
  result: CardMutationResult
}

export interface PendingConfirmationsResponse {
  confirmations: ConfirmationRequest[]
}

export interface ConfirmationDecisionResponse {
  result: ConfirmationDecisionResult
}

export interface MobileHttpRequest {
  method: string
  path: string
  body: string
  accessToken: string
}

export interface MobileHttpResponse {
  statusCode: number
  body: string
}

export interface MobileHttpTransport {
  send(request: MobileHttpRequest): Promise<MobileHttpResponse>
}
