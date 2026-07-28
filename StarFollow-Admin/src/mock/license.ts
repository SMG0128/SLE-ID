import type { License } from '@/types/license'
import { POLICY_OPTIONS } from '@/types/license'

function makePolicies(enabledKeys: string[]): License['policies'] {
  return POLICY_OPTIONS.map(p => ({ ...p, enabled: enabledKeys.includes(p.key) }))
}

const licenses: License[] = [
  {
    id: 'LC-001', name: '正门区域许可', zone: '正门大厅', status: '有效', cardCount: 12,
    policies: makePolicies(['record_event', 'allow_execute', 'double_confirm', 'abnormal_alarm']),
    creator: '张三', createTime: '2026-07-20', expireTime: '2026-12-31',
  },
  {
    id: 'LC-002', name: '机房专属许可', zone: 'B1机房', status: '有效', cardCount: 3,
    policies: makePolicies(['record_event', 'allow_execute', 'abnormal_alarm']),
    creator: '张三', createTime: '2026-07-15', expireTime: '2026-09-30',
  },
  {
    id: 'LC-003', name: '走廊通行许可', zone: '3F走廊', status: '即将过期', cardCount: 8,
    policies: makePolicies(['record_event', 'allow_execute']),
    creator: '李四', createTime: '2026-06-01', expireTime: '2026-08-02',
  },
  {
    id: 'LC-004', name: '车库车辆许可', zone: '地下车库', status: '已过期', cardCount: 5,
    policies: makePolicies(['record_event', 'allow_execute', 'double_confirm']),
    creator: '张三', createTime: '2026-01-10', expireTime: '2026-06-30',
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
