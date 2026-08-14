export interface PendingConfirmation {
  id: string
  requestId: number
  eventId: number
  eventKey: string | null
  cardId: string
  permissionId: number
  state: 'pending'
  expiresAt: string
  receivedAt: string
}

export interface ConfirmationDecisionResult {
  id: string
  decision: 'approve' | 'reject'
  success: boolean
  requestId: number
  status: number
  attempts: number
}
