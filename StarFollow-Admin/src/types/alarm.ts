/** 报警等级 */
export type AlarmLevel = 'severe' | 'high' | 'normal'

/** 报警类型 */
export type AlarmType =
  | 'unknown_device' | 'unauthorized' | 'license_expired'
  | 'key_failed' | 'confirm_failed' | 'execute_failed' | 'suspected_replay'

/** 报警记录 */
export interface AlarmRecord {
  id: string
  level: AlarmLevel
  type: AlarmType
  device: string
  cardId: string
  message: string
  operator: string
  time: string
  handled: boolean
  solution: string
}

/** 报警查询参数 */
export interface AlarmQuery {
  page: number
  pageSize: number
  level?: AlarmLevel | ''
  type?: AlarmType | ''
  handleStatus?: 'unhandled' | 'handled' | ''
}

/** 报警统计 */
export interface AlarmStats {
  severe: number
  high: number
  normal: number
  total: number
  unhandled: number
}

/** 报警列表响应 */
export interface AlarmListResponse {
  stats: AlarmStats
  total: number
  list: AlarmRecord[]
}

/** 报警类型定义表 */
export const ALARM_TYPES: { label: string; value: AlarmType }[] = [
  { label: '未知设备', value: 'unknown_device' },
  { label: '未授权', value: 'unauthorized' },
  { label: '许可过期', value: 'license_expired' },
  { label: '密钥失败', value: 'key_failed' },
  { label: '确认失败', value: 'confirm_failed' },
  { label: '执行失败', value: 'execute_failed' },
  { label: '疑似重放', value: 'suspected_replay' },
]

/** 报警等级定义表 */
export const ALARM_LEVELS: { label: string; value: AlarmLevel }[] = [
  { label: '严重', value: 'severe' },
  { label: '高', value: 'high' },
  { label: '普通', value: 'normal' },
]

/** 报警处理方案 */
export const ALARM_SOLUTIONS: Record<AlarmType, string> = {
  unknown_device: '确认设备身份，更新白名单后重新接入',
  unauthorized: '检查卡片权限配置，联系管理员授权',
  license_expired: '更新许可有效期，或重新签发许可',
  key_failed: '重新协商密钥对，检查 WS63 加密模块状态',
  confirm_failed: '二次确认超时，建议重试或人工介入',
  execute_failed: '检查检测端固件版本，进行远程重启后重试',
  suspected_replay: '标记为可疑事件，建议临时冻结相关卡片',
}
