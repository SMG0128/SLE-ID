export type AlarmLevel = 'severe' | 'high' | 'normal'
export type AlarmType =
  | 'unknown_device'
  | 'unauthorized'
  | 'license_expired'
  | 'lost_report'
  | 'key_failed'
  | 'suspected_replay'
  | 'confirm_rejected'
  | 'execute_failed'

export interface HardwareHeartbeat {
  gatewaySourceId: number
  gatewayBootId: number
  uptimeMs: number
  firmwareVersion: number
  policyVersion: number
  queueDepth: number
  hostOnline: boolean
  queueOverflows: number
  framesSent: number
  receivedAt: string
}

export interface HardwareEvent {
  eventKey: string
  eventId: number
  sourceId: number
  bootId: number
  cardAnonId: number
  permissionId: number
  timestampMs: number
  direction: number
  auth: number
  action: number
  confirm: number
  execution: number
  reason: number
  distanceCm: number
  confidence: number
  state: number
  decisionTimestampMs: number
  result: '成功' | '失败' | '待定'
  status: string
  receivedAt: string
}

export interface HardwareAlarm {
  type: AlarmType
  level: AlarmLevel
  message: string
  solution: string
}

export interface HardwareConfirmation {
  gatewaySourceId: number
  gatewayBootId: number
  requestId: number
  eventId: number
  cardAnonId: number
  permissionId: number
  deviceTimestampMs: number
  action: number
  direction: number
  expiresAt: string
  receivedAt: string
}

export interface SerialConfigRecord {
  port: string
  baudRate: number
  autoReconnect: boolean
}

export function formatDeviceId(sourceId: number): string {
  return `DEV-${(sourceId >>> 0).toString(16).toUpperCase().padStart(8, '0')}`
}

export function formatCardId(cardId: number): string {
  return `CARD-${(cardId >>> 0).toString(16).toUpperCase().padStart(8, '0')}`
}

export function formatEventKey(sourceId: number, bootId: number, eventId: number): string {
  return `EV-${(sourceId >>> 0).toString(16).toUpperCase().padStart(8, '0')}-${(bootId >>> 0).toString(16).toUpperCase().padStart(8, '0')}-${(eventId >>> 0).toString().padStart(10, '0')}`
}

export function formatFirmware(version: number): string {
  return `v${(version >>> 16) & 0xff}.${(version >>> 8) & 0xff}.${version & 0xff}`
}

export function alarmFor(reason: number, execution: number): HardwareAlarm {
  if (execution === 3 || reason === 17) {
    return { type: 'execute_failed', level: 'high', message: '权限通过但执行器输出失败', solution: '检查检测端与执行器接线，并复核执行反馈' }
  }
  switch (reason) {
    case 4:
      return { type: 'license_expired', level: 'high', message: '许可已过期', solution: '更新许可有效期或重新签发许可' }
    case 7:
      return { type: 'lost_report', level: 'severe', message: '检测到已挂失卡片', solution: '保持拒绝并核查持有人与卡片状态' }
    case 10:
      return { type: 'key_failed', level: 'severe', message: '卡片密钥认证失败', solution: '检查密钥版本并重新安全写卡' }
    case 11:
      return { type: 'suspected_replay', level: 'severe', message: '检测到疑似重放', solution: '冻结相关凭证并检查计数器与挑战响应' }
    case 14:
    case 15:
    case 16:
      return { type: 'confirm_rejected', level: 'high', message: '管理确认被拒绝、超时或离线', solution: '检查确认链路和许可确认策略' }
    default:
      return { type: 'unauthorized', level: 'normal', message: '未授权通行被拒绝', solution: '检查卡片许可、范围、时间与次数限制' }
  }
}

export function eventResult(auth: number, confirm: number, execution: number, reason: number): '成功' | '失败' | '待定' {
  if (confirm === 1 || execution === 1) return '待定'
  if (reason !== 0 || auth > 1 || execution === 3 || confirm >= 3) return '失败'
  return auth === 1 ? '成功' : '待定'
}

export function eventStatus(action: number, confirm: number, execution: number, reason: number): string {
  const actions = ['记录', '等待确认', '执行', '拒绝', '报警']
  const confirmations = ['无需确认', '待确认', '已批准', '已拒绝', '确认超时', '后端离线']
  const executions = ['未请求执行', '执行中', '执行成功', '执行失败']
  return `${actions[action] ?? `动作${action}`} / ${confirmations[confirm] ?? `确认${confirm}`} / ${executions[execution] ?? `执行${execution}`} / reason=${reason}`
}
