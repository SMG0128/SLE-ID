/** 报警等级 */
export type AlarmLevel = 'severe' | 'high' | 'normal'

/** 报警类型（文档 4.4/4.5） */
export type AlarmType =
  | 'unknown_device'      // 未知设备
  | 'unauthorized'        // 未授权
  | 'license_expired'     // 过期
  | 'lost_report'         // 挂失
  | 'key_failed'          // 密钥失败
  | 'suspected_replay'    // 疑似重放
  | 'confirm_rejected'    // 确认拒绝/超时
  | 'execute_failed'      // 执行失败

/** 报警处理状态 */
export type AlarmHandleStatus = 'unhandled' | 'handled' | 'ignored' | 'escalated'

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
  handleStatus: AlarmHandleStatus
  solution: string
}

/** 报警查询参数 */
export interface AlarmQuery {
  page: number
  pageSize: number
  level?: AlarmLevel | ''
  type?: AlarmType | ''
  handleStatus?: AlarmHandleStatus | ''
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
  { label: '挂失', value: 'lost_report' },
  { label: '密钥失败', value: 'key_failed' },
  { label: '疑似重放', value: 'suspected_replay' },
  { label: '确认拒绝/超时', value: 'confirm_rejected' },
  { label: '执行失败', value: 'execute_failed' },
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
  unauthorized: '检查卡片权限配置，按许可策略执行未授权处理',
  license_expired: '更新许可有效期，或重新签发许可',
  lost_report: '卡片已挂失，立即拒绝并建议临时冻结相关许可',
  key_failed: '重新协商密钥对，检查 WS63 加密模块状态',
  suspected_replay: '挑战值或计数异常，标记可疑并临时封禁',
  confirm_rejected: '二次确认被拒绝或超时，写入确认结果，由许可策略决定是否升级',
  execute_failed: '权限已通过但闸机/门锁未执行，检查检测端并远程重启后重试',
}
