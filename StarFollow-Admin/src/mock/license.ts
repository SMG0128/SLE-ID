import type { License, LicensePolicy } from '@/types/license'
import { defaultPolicy } from '@/types/license'

function makePolicy(partial: Partial<LicensePolicy>): LicensePolicy {
  return { ...defaultPolicy(), ...partial }
}

const licenses: License[] = [
  {
    id: 'LC-001', name: '正门区域许可', zone: '正门大厅', status: '有效', cardCount: 12,
    policies: makePolicy({ recordEvent: true, allowExecute: true, forceConfirm: false, unauthorizedAction: 'alarm', direction: 'both' }),
    keyVersion: 3, lastSync: '2026-08-05 16:00', creator: '张三', createTime: '2026-07-20', expireTime: '2026-12-31',
  },
  {
    id: 'LC-002', name: '机房专属许可', zone: 'B1机房', status: '有效', cardCount: 3,
    policies: makePolicy({ recordEvent: true, allowExecute: true, forceConfirm: true, unauthorizedAction: 'alarm', usageLimit: { type: 'fixed', count: 50 }, offlineAllowed: false }),
    keyVersion: 2, lastSync: '2026-08-05 15:40', creator: '张三', createTime: '2026-07-15', expireTime: '2026-09-30',
  },
  {
    id: 'LC-003', name: '走廊通行许可', zone: '3F走廊', status: '即将过期', cardCount: 8,
    policies: makePolicy({ recordEvent: true, allowExecute: true, forceConfirm: false, unauthorizedAction: 'remind', timeLimit: { enabled: true, startDate: '2026-06-01', endDate: '2026-08-02', dailyStart: '07:00', dailyEnd: '22:00', specialDates: [] } }),
    keyVersion: 1, lastSync: '2026-08-03 09:00', creator: '李四', createTime: '2026-06-01', expireTime: '2026-08-02',
  },
  {
    id: 'LC-004', name: '签到专用许可', zone: '1F仓库', status: '已过期', cardCount: 20,
    policies: makePolicy({ recordEvent: true, allowExecute: false, unauthorizedAction: 'log', usageLimit: { type: 'once', count: 1 }, direction: 'in' }),
    keyVersion: 1, lastSync: '2026-07-01 08:00', creator: '张三', createTime: '2026-01-10', expireTime: '2026-06-30',
  },
]

/** 获取许可列表 */
export function mockLicenseList(): License[] {
  return [...licenses]
}

/** 新增许可（内存） */
export function mockAddLicense(license: License): void {
  licenses.unshift(license)
}

/** 移除许可（内存） */
export function mockRemoveLicense(id: string): void {
  const idx = licenses.findIndex(l => l.id === id)
  if (idx >= 0) licenses.splice(idx, 1)
}
