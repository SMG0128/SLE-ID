import request from './request'

export interface PermissionUser {
  id: string
  name: string
  role: string
  permissions: string[]
  status: string
  lastLogin: string
  createdAt: string
}

/** 获取许可用户列表 */
export function getPermissionUsers(params: { page: number; pageSize: number }): Promise<{ total: number; list: PermissionUser[] }> {
  return request({ url: '/permissions/users', method: 'get', params })
}

/** 更新用户权限 */
export function updateUserPermission(id: string, permissions: string[]): Promise<void> {
  return request({ url: `/permissions/users/${id}`, method: 'put', data: { permissions } })
}

/** 获取邀请码列表 */
export function getInviteList(params: { page: number; pageSize: number }): Promise<{ total: number; list: unknown[] }> {
  return request({ url: '/permissions/invites', method: 'get', params })
}

/** 生成邀请码 */
export function generateInviteCode(config: { role: string; expireDays: number; maxUses: number }): Promise<{ code: string }> {
  return request({ url: '/permissions/invites', method: 'post', data: config })
}
