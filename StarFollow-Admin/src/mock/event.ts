import type { EventLogItem, EventQuery, EventListResponse, RealtimeEvent, EventStatus, AuthResult } from '@/types/event'
import { STATUS_ORDER } from '@/types/event'

const devicePool = ['正门检测端', '走廊检测端', '机房检测端', '车库检测端', '会议室检测端', '仓库检测端']
const cardPool = Array.from({ length: 20 }, (_, i) => `ANON-${String(i + 1).padStart(4, '0')}`)
const ownerPool = ['张三', '李四', '王五', '赵六', '孙七', '周八']
const resultPool: EventLogItem['result'][] = ['成功', '成功', '成功', '成功', '失败', '待定']
const statusPool = ['待命中', '接近中', '区域内', '已完成', '冷却中', '已拒绝']

function rand<T>(arr: T[]): T { return arr[Math.floor(Math.random() * arr.length)] }

/** 生成事件日志列表 */
export function mockEventList(query: EventQuery): EventListResponse {
  const pageSize = query.pageSize || 10
  const total = 81
  const list: EventLogItem[] = []
  let id = 1000

  for (let d = total - 1; d >= 0; d--) {
    const date = new Date(2026, 6, 27, 0, 0, 0)
    date.setMinutes(date.getMinutes() - d * 12 + Math.floor(Math.random() * 5))
    list.push({
      eventId: `EV-${String(id++).padStart(6, '0')}`,
      time: date.toLocaleString('zh-CN'),
      dateStr: date.toISOString().slice(0, 10),
      device: rand(devicePool),
      cardId: rand(cardPool),
      owner: rand(ownerPool),
      result: rand(resultPool),
      status: rand(statusPool),
    })
  }

  // 筛选（文档 4.4：按人/卡片/检测点/时间）
  let filtered = list
  if (query.device) filtered = filtered.filter(i => i.device === query.device)
  if (query.cardId) filtered = filtered.filter(i => i.cardId === query.cardId)
  if (query.owner) filtered = filtered.filter(i => i.owner === query.owner)
  if (query.result) filtered = filtered.filter(i => i.result === query.result)
  if (query.dateStart) filtered = filtered.filter(i => i.dateStr >= query.dateStart!)
  if (query.dateEnd) filtered = filtered.filter(i => i.dateStr <= query.dateEnd!)

  const start = ((query.page || 1) - 1) * pageSize
  return { total: filtered.length, list: filtered.slice(start, start + pageSize) }
}

/** 实时事件模拟引擎：推进生命周期 + 生成新事件 */
export function mockRealtimeTick(
  current: RealtimeEvent[],
  autoRefresh: boolean,
  counter: { value: number },
): RealtimeEvent[] {
  // 推进已有事件状态
  const next = current
    .map(event => {
      const idx = STATUS_ORDER.indexOf(event.status)
      if (idx < 0 || idx >= STATUS_ORDER.length - 1) return event
      const nextStatus = STATUS_ORDER[idx + 1]
      return {
        ...event,
        status: nextStatus,
        authResult: (nextStatus === 'COMPLETED'
          ? (Math.random() > 0.1 ? '成功' : '失败')
          : event.authResult) as AuthResult,
        time: new Date().toLocaleString('zh-CN'),
      }
    })
    .filter(event => event.status !== 'COOLDOWN')

  // 生成新事件
  if (autoRefresh) {
    const count = Math.random() > 0.4 ? 1 : 2
    for (let i = 0; i < count; i++) {
      next.push({
        eventId: `EV-${String(counter.value).padStart(6, '0')}`,
        cardId: `CARD${String(Math.floor(Math.random() * 10) + 1).padStart(3, '0')}`,
        device: rand(devicePool),
        status: 'IDLE' as EventStatus,
        authResult: '' as AuthResult,
        time: new Date().toLocaleString('zh-CN'),
      })
      counter.value++
    }
  }

  return next.slice(-20)
}
