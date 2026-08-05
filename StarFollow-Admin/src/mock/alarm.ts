import type { AlarmRecord, AlarmQuery, AlarmListResponse } from '@/types/alarm'
import { ALARM_TYPES, ALARM_LEVELS, ALARM_SOLUTIONS, type AlarmType, type AlarmLevel } from '@/types/alarm'

const devicePool = ['正门检测端', '走廊检测端', '机房检测端', '车库检测端', '会议室检测端', '仓库检测端']
const operatorPool = ['系统自动', '系统自动', '系统自动', '张三', '李四']

function levelForType(type: AlarmType): AlarmLevel {
  if (type === 'suspected_replay' || type === 'key_failed' || type === 'lost_report') return 'severe'
  if (type === 'unauthorized' || type === 'execute_failed' || type === 'confirm_rejected') return 'high'
  return 'normal'
}

/** 生成报警列表 */
export function mockAlarmList(query: AlarmQuery): AlarmListResponse {
  const list: AlarmRecord[] = []
  let id = 1

  for (const at of ALARM_TYPES) {
    for (let i = 0; i < 2; i++) {
      const now = new Date()
      now.setMinutes(now.getMinutes() - (id * 19 + i * 7))
      list.push({
        id: `ALM-${String(id++).padStart(6, '0')}`,
        level: levelForType(at.value),
        type: at.value,
        device: devicePool[Math.floor(Math.random() * devicePool.length)],
        cardId: `ANON-${String(Math.floor(Math.random() * 9000) + 1000)}`,
        message: `${at.label}报警触发`,
        operator: operatorPool[Math.floor(Math.random() * operatorPool.length)],
        time: now.toLocaleString('zh-CN'),
        handleStatus: i === 0 ? 'unhandled' : 'handled',
        solution: ALARM_SOLUTIONS[at.value] || '待人工分析',
      })
    }
  }

  // 筛选
  let filtered = list
  if (query.level) filtered = filtered.filter(a => a.level === query.level)
  if (query.type) filtered = filtered.filter(a => a.type === query.type)
  if (query.handleStatus) filtered = filtered.filter(a => a.handleStatus === query.handleStatus)

  const pageSize = query.pageSize || 10
  const start = ((query.page || 1) - 1) * pageSize

  return {
    stats: {
      severe: list.filter(a => a.level === 'severe').length,
      high: list.filter(a => a.level === 'high').length,
      normal: list.filter(a => a.level === 'normal').length,
      total: list.length,
      unhandled: list.filter(a => a.handleStatus === 'unhandled').length,
    },
    total: filtered.length,
    list: filtered.slice(start, start + pageSize),
  }
}
