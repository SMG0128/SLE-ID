/** 报警级别 */
export enum AlarmLevel {
  Low = 'low',
  Medium = 'medium',
  High = 'high',
  Urgent = 'urgent',
}

/** 报警规则操作符 */
export enum AlarmOperator {
  GT = 'gt',
  LT = 'lt',
  EQ = 'eq',
  GTE = 'gte',
  LTE = 'lte',
}

/** 报警处理状态 */
export enum AlarmHandleStatus {
  Unconfirmed = 'unconfirmed',
  Confirmed = 'confirmed',
  Processing = 'processing',
  Resolved = 'resolved',
}

/** 报警规则 */
export interface AlarmRule {
  id: string
  name: string
  deviceId: string
  deviceName: string
  eventType: string
  field: string
  operator: AlarmOperator
  threshold: number
  level: AlarmLevel
  enabled: boolean
  cooldown: number
  createdAt: string
  updatedAt: string
}

/** 报警记录 */
export interface AlarmRecord {
  id: string
  ruleId: string
  ruleName: string
  eventId: string
  deviceId: string
  deviceName: string
  level: AlarmLevel
  message: string
  value: number
  threshold: number
  handler?: string
  handleStatus: AlarmHandleStatus
  handleNote?: string
  handleTime?: string
  createdAt: string
}

/** 报警统计 */
export interface AlarmStats {
  total: number
  unconfirmed: number
  confirmed: number
  processing: number
  resolved: number
  highUrgent: number
  todayNew: number
}

/** 报警查询参数 */
export interface AlarmQuery {
  page: number
  pageSize: number
  level?: AlarmLevel
  handleStatus?: AlarmHandleStatus
  deviceId?: string
  startTime?: string
  endTime?: string
}

/** 报警列表响应 */
export interface AlarmListResponse {
  stats: AlarmStats
  total: number
  list: AlarmRecord[]
}
