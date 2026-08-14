import request from './request'
import type { EventQuery, EventListResponse } from '@/types/event'

export function getEventList(query: EventQuery): Promise<EventListResponse> {
  return request.get<never, EventListResponse>('/events', { params: query })
}
