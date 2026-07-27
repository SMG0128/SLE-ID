import request from './request'
import type { AlarmQuery, AlarmListResponse, AlarmRecord } from '@/types/alarm'

/** 获取报警列表 */
export function getAlarmList(params: AlarmQuery): Promise<AlarmListResponse> {
  return request({ url: '/alarms', method: 'get', params })
}

/** 获取报警详情 */
export function getAlarmDetail(id: string): Promise<AlarmRecord> {
  return request({ url: `/alarms/${id}`, method: 'get' })
}

/** 确认报警 */
export function confirmAlarm(id: string, note?: string): Promise<void> {
  return request({ url: `/alarms/${id}/confirm`, method: 'post', data: { note } })
}

/** 处理报警 */
export function handleAlarm(id: string, note: string): Promise<void> {
  return request({ url: `/alarms/${id}/handle`, method: 'post', data: { note } })
}

/** 解决报警 */
export function resolveAlarm(id: string, note: string): Promise<void> {
  return request({ url: `/alarms/${id}/resolve`, method: 'post', data: { note } })
}
