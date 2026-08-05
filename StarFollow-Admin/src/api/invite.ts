import { mockInviteList, mockCreateInvite, mockRevokeInvite } from '@/mock/invite'
import { mockDelay } from './request'
import type { InviteCode, InviteListResponse, CreateInviteForm } from '@/types/invite'

/** 获取邀请码列表 */
export function getInviteList(): Promise<InviteListResponse> {
  return mockDelay(mockInviteList())
}

/** 生成一次性邀请码 */
export function createInvite(form: CreateInviteForm): Promise<InviteCode> {
  return mockDelay(mockCreateInvite(form), 100)
}

/** 撤销邀请码 */
export function revokeInvite(id: string, reason: string): Promise<void> {
  mockRevokeInvite(id, reason)
  return mockDelay(undefined, 100)
}
