/** 感知事件类型 */
export enum EventType {
  Motion = 'motion',
  Sound = 'sound',
  Temperature = 'temperature',
  Humidity = 'humidity',
  Vibration = 'vibration',
  Intrusion = 'intrusion',
  Other = 'other',
}

/** 事件严重级别 */
export enum EventSeverity {
  Info = 'info',
  Warning = 'warning',
  Critical = 'critical',
}

/** 事件处理状态 */
export enum EventStatus {
  Pending = 'pending',
  Processing = 'processing',
  Resolved = 'resolved',
  Ignored = 'ignored',
}

/** 感知事件 */
export interface SensingEvent {
  id: string
  deviceId: string
  deviceName: string
  type: EventType
  severity: EventSeverity
  status: EventStatus
  title: string
  description: string
  location: string
  value: number
  unit: string
  snapshot?: string
  createdAt: string
  updatedAt: string
}

/** 事件查询参数 */
export interface EventQuery {
  page: number
  pageSize: number
  type?: EventType
  severity?: EventSeverity
  status?: EventStatus
  deviceId?: string
  startTime?: string
  endTime?: string
  keyword?: string
}

/** 事件列表响应 */
export interface EventListResponse {
  total: number
  list: SensingEvent[]
}
