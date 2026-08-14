/** 邀请码状态 */
export type InviteStatus = '未使用' | '已绑定' | '已过期' | '已撤销'

/** 邀请码（一次性、可过期、可撤销、可追踪绑定，文档 4.4） */
export interface InviteCode {
  id: string
  code: string
  role: string            // 绑定角色
  status: InviteStatus
  usedBy: string          // 绑定的用户/卡片标识
  usedAt: string | null   // 绑定时间
  expireAt: string        // 过期时间
  createdAt: string
  revokeReason: string    // 失效原因
  oneTime: boolean        // 是否一次性
  maxUses?: number
  usedCount?: number
  remainingUses?: number
}

/** 生成邀请码表单 */
export interface CreateInviteForm {
  role: string
  expireDays: number
  maxUses: number
}

/** 邀请码列表响应 */
export interface InviteListResponse {
  total: number
  list: InviteCode[]
}
