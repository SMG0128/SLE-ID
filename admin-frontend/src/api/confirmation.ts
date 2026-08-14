import request from './request'
import type { ConfirmationDecisionResult, PendingConfirmation } from '@/types/confirmation'

export function getPendingConfirmations(): Promise<PendingConfirmation[]> {
  return request.get<never, PendingConfirmation[]>('/confirmations/pending')
}

export function decideConfirmation(id: string, decision: 'approve' | 'reject'): Promise<ConfirmationDecisionResult> {
  return request.post<never, ConfirmationDecisionResult>(`/confirmations/${encodeURIComponent(id)}/decision`, { decision })
}
