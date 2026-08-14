import {
  InvitationPreviewResult,
  InvitationRedemptionResult
} from '../models/Invitation'

export interface InvitationService {
  validateInvitationFormat(code: string): boolean
  previewInvitation(code: string): Promise<InvitationPreviewResult>
  redeemInvitation(code: string): Promise<InvitationRedemptionResult>
  isInvitationUsed(code: string): Promise<boolean>
  isAuthorizationBound(authorizationId: string): Promise<boolean>
}
