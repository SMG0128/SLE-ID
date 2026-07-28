import { mockAlarmList } from '@/mock/alarm'
import { mockDelay } from './request'
import type { AlarmQuery, AlarmListResponse, AlarmRecord } from '@/types/alarm'

/** 获取报警列表 — page → api → mock */
export function getAlarmList(query: AlarmQuery): Promise<AlarmListResponse> {
  // TODO: 后端就绪 → return request.get('/alarms', { params: query })
  return mockDelay(mockAlarmList(query))
}

/** 标记报警已处理（本地 Mock 写入） */
export function handleAlarm(id: string): Promise<void> {
  // TODO: 后端就绪 → return request.post(`/alarms/${id}/handle`)
  return mockDelay(undefined, 100)
}
