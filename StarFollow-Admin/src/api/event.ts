import request from './request'
import type { EventQuery, EventListResponse, SensingEvent } from '@/types/event'

/** 获取事件列表 */
export function getEventList(params: EventQuery): Promise<EventListResponse> {
  return request({ url: '/events', method: 'get', params })
}

/** 获取事件详情 */
export function getEventDetail(id: string): Promise<SensingEvent> {
  return request({ url: `/events/${id}`, method: 'get' })
}

/** 处理事件 */
export function handleEvent(id: string, action: string, note?: string): Promise<void> {
  return request({ url: `/events/${id}/handle`, method: 'post', data: { action, note } })
}
