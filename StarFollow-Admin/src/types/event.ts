/** 实时事件状态（星闪主动感知生命周期） */
export type EventStatus = 'IDLE' | 'APPROACHING' | 'IN_ZONE' | 'COMPLETED' | 'COOLDOWN'

/** 认证结果 */
export type AuthResult = '' | '成功' | '失败'

/** 事件日志记录（文档 4.4：按人/卡片/检测点/时间筛选） */
export interface EventLogItem {
  eventId: string
  time: string
  dateStr: string
  device: string
  cardId: string
  owner: string
  result: '成功' | '失败' | '待定'
  status: string
}

/** 实时检测事件 */
export interface RealtimeEvent {
  eventId: string
  cardId: string
  device: string
  status: EventStatus
  authResult: AuthResult
  time: string
}

/** 事件日志查询参数 */
export interface EventQuery {
  page: number
  pageSize: number
  device?: string
  cardId?: string
  owner?: string
  result?: string
  dateStart?: string
  dateEnd?: string
}

/** 事件日志列表响应 */
export interface EventListResponse {
  total: number
  list: EventLogItem[]
}

/** 状态流转顺序 */
export const STATUS_ORDER: EventStatus[] = ['IDLE', 'APPROACHING', 'IN_ZONE', 'COMPLETED', 'COOLDOWN']
