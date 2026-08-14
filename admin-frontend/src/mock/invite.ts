import type { InviteCode, InviteListResponse, CreateInviteForm } from '@/types/invite'

const invites: InviteCode[] = [
  { id: 'IV-001', code: 'SF-ADMIN-8K3X', role: '管理员', status: '未使用', usedBy: '-', usedAt: null, expireAt: '2026-08-20', createdAt: '2026-08-01 10:00', revokeReason: '', oneTime: true },
  { id: 'IV-002', code: 'SF-OPER-2M9K', role: '操作员', status: '已绑定', usedBy: '李四', usedAt: '2026-08-03 14:22', expireAt: '2026-08-15', createdAt: '2026-08-01 10:05', revokeReason: '', oneTime: true },
  { id: 'IV-003', code: 'SF-VIEW-5P2B', role: '查看者', status: '已过期', usedBy: '-', usedAt: null, expireAt: '2026-07-30', createdAt: '2026-07-10 09:00', revokeReason: '超过有效期未使用', oneTime: true },
  { id: 'IV-004', code: 'SF-OPER-7D1Q', role: '操作员', status: '已撤销', usedBy: '-', usedAt: null, expireAt: '2026-09-01', createdAt: '2026-07-28 16:30', revokeReason: '管理员手动撤销', oneTime: true },
]

/** 获取邀请码列表 */
export function mockInviteList(): InviteListResponse {
  return { total: invites.length, list: [...invites] }
}

/** 生成邀请码（一次性） */
export function mockCreateInvite(form: CreateInviteForm): InviteCode {
  const now = new Date()
  const expire = new Date(now.getTime() + form.expireDays * 86400000)
  const code = `SF-${form.role.toUpperCase().slice(0, 4)}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`
  const invite: InviteCode = {
    id: `IV-${String(Date.now()).slice(-4)}`,
    code,
    role: form.role,
    status: '未使用',
    usedBy: '-',
    usedAt: null,
    expireAt: expire.toISOString().slice(0, 10),
    createdAt: now.toISOString().replace('T', ' ').slice(0, 19),
    revokeReason: '',
    oneTime: form.maxUses <= 1,
  }
  invites.unshift(invite)
  return invite
}

/** 撤销邀请码 */
export function mockRevokeInvite(id: string, reason: string): void {
  const target = invites.find(i => i.id === id)
  if (target) {
    target.status = '已撤销'
    target.revokeReason = reason
  }
}
