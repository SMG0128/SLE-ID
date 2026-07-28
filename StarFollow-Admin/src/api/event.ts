import { mockEventList, mockRealtimeTick } from '@/mock/event'
import { mockDelay } from './request'
import type { EventQuery, EventListResponse, RealtimeEvent } from '@/types/event'

/** 获取事件日志列表 — page → api → mock */
export function getEventList(query: EventQuery): Promise<EventListResponse> {
  // TODO: 后端就绪 → return request.get('/events', { params: query })
  return mockDelay(mockEventList(query))
}

/** 实时事件模拟引擎推进 — EventMonitor 每 5 秒调用 */
export function tickRealtimeEvents(
  current: RealtimeEvent[],
  autoRefresh: boolean,
  counter: { value: number },
): Promise<RealtimeEvent[]> {
  return mockDelay(mockRealtimeTick(current, autoRefresh, counter), 100)
}
