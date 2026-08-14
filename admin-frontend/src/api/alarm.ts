import request from './request'
import type { AlarmQuery, AlarmListResponse, AlarmRecord } from '@/types/alarm'

export function getAlarmList(query: AlarmQuery): Promise<AlarmListResponse> {
  return request.get<never, AlarmListResponse>('/alarms', { params: query })
}

/** 标记报警已处理（本地 Mock 写入） */
export function handleAlarm(id: string, status: AlarmRecord['handleStatus']): Promise<void> {
  return request.post<never, void>(`/alarms/${encodeURIComponent(id)}/handle`, { status })
}
