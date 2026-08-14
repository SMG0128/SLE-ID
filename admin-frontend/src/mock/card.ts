import type { Card, CardListResponse, CardAction } from '@/types/card'

const cards: Card[] = [
  { id: 'CD-001', cardId: 'ANON-1001', owner: '张三', licenseId: 'LC-001', licenseName: '正门区域许可', status: '正常', keyVersion: 3, lastSync: '2026-08-05 16:00', createdAt: '2026-07-20' },
  { id: 'CD-002', cardId: 'ANON-1002', owner: '李四', licenseId: 'LC-003', licenseName: '走廊通行许可', status: '正常', keyVersion: 1, lastSync: '2026-08-03 09:00', createdAt: '2026-06-01' },
  { id: 'CD-003', cardId: 'ANON-1003', owner: '王五', licenseId: 'LC-002', licenseName: '机房专属许可', status: '已冻结', keyVersion: 2, lastSync: '2026-08-02 11:20', createdAt: '2026-07-15' },
  { id: 'CD-004', cardId: 'ANON-1004', owner: '赵六', licenseId: 'LC-001', licenseName: '正门区域许可', status: '已挂失', keyVersion: 3, lastSync: '2026-08-04 18:45', createdAt: '2026-07-21' },
  { id: 'CD-005', cardId: 'ANON-1005', owner: '孙七', licenseId: 'LC-004', licenseName: '签到专用许可', status: '已撤销', keyVersion: 1, lastSync: '2026-07-01 08:00', createdAt: '2026-01-10' },
  { id: 'CD-006', cardId: 'ANON-1006', owner: '周八', licenseId: 'LC-002', licenseName: '机房专属许可', status: '正常', keyVersion: 2, lastSync: '2026-08-05 15:40', createdAt: '2026-07-16' },
]

/** 获取卡片列表 */
export function mockCardList(): CardListResponse {
  return { total: cards.length, list: [...cards] }
}

/** 卡片操作：撤销/冻结/挂失/恢复 */
export function mockCardAction(cardId: string, action: CardAction): Card | undefined {
  const target = cards.find(c => c.cardId === cardId)
  if (!target) return undefined
  const statusMap: Record<CardAction, Card['status']> = {
    revoke: '已撤销',
    freeze: '已冻结',
    report_lost: '已挂失',
    restore: '正常',
  }
  target.status = statusMap[action]
  target.lastSync = new Date().toISOString().replace('T', ' ').slice(0, 19)
  return target
}
