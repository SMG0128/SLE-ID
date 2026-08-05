import { mockLicenseList, mockAddLicense, mockRemoveLicense } from '@/mock/license'
import { mockDelay } from './request'
import type { License, CreateLicenseForm } from '@/types/license'
import { defaultPolicy } from '@/types/license'

/** 获取许可列表 — page → api → mock */
export function getLicenses(): Promise<License[]> {
  // TODO: 后端就绪 → return request.get('/licenses')
  return mockDelay(mockLicenseList())
}

/** 创建许可（组合策略） */
export function createLicense(form: CreateLicenseForm, creator: string): Promise<License> {
  const now = new Date().toISOString().slice(0, 10)
  const [, expire] = form.dateRange ?? [now, now]
  const status: License['status'] =
    expire < now ? '已过期'
    : new Date(expire).getTime() - Date.now() < 7 * 86400000 ? '即将过期' : '有效'

  const license: License = {
    id: `LC-${String(Date.now()).slice(-3)}`,
    name: form.name,
    zone: form.zone,
    status,
    cardCount: 0,
    policies: { ...defaultPolicy(), ...form.policies },
    keyVersion: 1,
    lastSync: now,
    creator,
    createTime: now,
    expireTime: expire,
  }

  mockAddLicense(license)
  return mockDelay(license, 100)
}

/** 吊销许可 */
export function revokeLicense(id: string): Promise<void> {
  mockRemoveLicense(id)
  return mockDelay(undefined, 100)
}
