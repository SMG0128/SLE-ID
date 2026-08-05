/** 未授权处理方式 */
export type UnauthorizedAction = 'none' | 'log' | 'remind' | 'alarm'

/** 次数限制类型 */
export type UsageLimitType = 'once' | 'fixed' | 'unlimited'

/** 方向与事件 */
export type DirectionType = 'in' | 'out' | 'both'

/** 时间限制配置 */
export interface TimeLimitConfig {
  enabled: boolean
  startDate: string | null        // 生效日期 YYYY-MM-DD
  endDate: string | null          // 失效日期 YYYY-MM-DD
  dailyStart: string | null       // 每日开始 HH:mm
  dailyEnd: string | null         // 每日结束 HH:mm
  specialDates: string[]          // 特殊日期
}

/** 次数限制配置 */
export interface UsageLimitConfig {
  type: UsageLimitType
  count: number                   // type=fixed 时的次数
}

/** 组合式发卡策略（10 项，文档 4.3） */
export interface LicensePolicy {
  recordEvent: boolean            // ① 记录事件
  allowExecute: boolean           // ② 允许执行
  forceConfirm: boolean           // ③ 管理端强制二次确认（优先级最高，用户不得取消）
  unauthorizedAction: UnauthorizedAction // ④ 未授权处理
  scope: string[]                 // ⑤ 适用范围（组织/检测端/区域/检测点）
  timeLimit: TimeLimitConfig      // ⑥ 时间限制
  usageLimit: UsageLimitConfig    // ⑦ 次数限制
  offlineAllowed: boolean         // ⑧ 离线许可
  huaweiFallback: boolean         // ⑨ 华为设备替代（手机临时通行）
  direction: DirectionType        // ⑩ 方向与事件
}

/** 许可状态 */
export type LicenseStatus = '有效' | '即将过期' | '已过期' | '已冻结' | '已挂失' | '已撤销'

/** 许可记录 */
export interface License {
  id: string
  name: string
  zone: string
  status: LicenseStatus
  cardCount: number
  policies: LicensePolicy
  keyVersion: number              // 密钥版本
  lastSync: string                // 最后同步时间
  creator: string
  createTime: string
  expireTime: string
}

/** 创建许可表单 */
export interface CreateLicenseForm {
  name: string
  zone: string
  dateRange: [string, string] | null
  policies: LicensePolicy
}

/** 策略模板（快捷入口，最终仍转换为字段） */
export interface PolicyTemplate {
  key: string
  name: string
  desc: string
  policies: LicensePolicy
}

/** 区域选项 */
export const ZONE_OPTIONS = ['正门大厅', '3F走廊', 'B1机房', '地下车库', '2F会议室', '1F仓库', '全区域']

/** 检测点选项（适用范围用） */
export const SCOPE_OPTIONS = ['正门检测端', '走廊检测端', '机房检测端', '车库检测端', '会议室检测端', '仓库检测端', '全检测端']

/** 新许可的默认策略 */
export function defaultPolicy(): LicensePolicy {
  return {
    recordEvent: true,
    allowExecute: false,
    forceConfirm: false,
    unauthorizedAction: 'log',
    scope: ['全检测端'],
    timeLimit: { enabled: false, startDate: null, endDate: null, dailyStart: null, dailyEnd: null, specialDates: [] },
    usageLimit: { type: 'unlimited', count: 1 },
    offlineAllowed: true,
    huaweiFallback: false,
    direction: 'both',
  }
}

/** 策略模板：签到 / 酒店 / 闸机（快捷入口，可再修改） */
export const POLICY_TEMPLATES: PolicyTemplate[] = [
  {
    key: 'signin',
    name: '签到模板',
    desc: '仅记录签到事件，不执行任何控制输出',
    policies: {
      ...defaultPolicy(),
      recordEvent: true,
      allowExecute: false,
      forceConfirm: false,
      unauthorizedAction: 'log',
      usageLimit: { type: 'once', count: 1 },
      offlineAllowed: true,
      direction: 'in',
    },
  },
  {
    key: 'hotel',
    name: '酒店模板',
    desc: '允许开锁执行 + 强制二次确认 + 限定日期',
    policies: {
      ...defaultPolicy(),
      recordEvent: true,
      allowExecute: true,
      forceConfirm: true,
      unauthorizedAction: 'remind',
      usageLimit: { type: 'fixed', count: 10 },
      offlineAllowed: true,
      direction: 'both',
    },
  },
  {
    key: 'gate',
    name: '闸机模板',
    desc: '允许执行 + 强制二次确认 + 未授权紧急报警',
    policies: {
      ...defaultPolicy(),
      recordEvent: true,
      allowExecute: true,
      forceConfirm: true,
      unauthorizedAction: 'alarm',
      usageLimit: { type: 'unlimited', count: 0 },
      offlineAllowed: false,
      huaweiFallback: true,
      direction: 'both',
    },
  },
]
