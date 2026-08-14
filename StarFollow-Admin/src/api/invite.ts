import request from './request'
import type { InviteCode, InviteListResponse, CreateInviteForm } from '@/types/invite'

/** 获取邀请码列表 */
export function getInviteList(): Promise<InviteListResponse> {
  return request.get<never, InviteListResponse>('/invites')
}

/** 生成一次性邀请码 */
export function createInvite(form: CreateInviteForm): Promise<InviteCode> {
  return request.post<never, InviteCode>('/invites', form)
}

/** 撤销邀请码 */
export function revokeInvite(id: string, reason: string): Promise<void> {
  return request.post<never, void>(`/invites/${encodeURIComponent(id)}/revoke`, { reason })
}
