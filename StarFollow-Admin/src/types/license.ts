/** 许可策略项 */
export interface PolicyOption {
  key: string
  label: string
  desc: string
  enabled: boolean
}

/** 许可记录 */
export interface License {
  id: string
  name: string
  zone: string
  status: '有效' | '即将过期' | '已过期'
  cardCount: number
  policies: PolicyOption[]
  creator: string
  createTime: string
  expireTime: string
}

/** 创建许可表单 */
export interface CreateLicenseForm {
  name: string
  zone: string
  dateRange: [string, string] | null
  policies: Record<string, boolean>
}

/** 策略定义表（体现项目创新：4 项可配置策略） */
export const POLICY_OPTIONS: Omit<PolicyOption, 'enabled'>[] = [
  { key: 'record_event', label: '记录事件', desc: '记录所有认证与检测事件日志' },
  { key: 'allow_execute', label: '允许执行', desc: '允许卡片执行开门/区域进入等操作' },
  { key: 'double_confirm', label: '二次确认', desc: '需要操作人员现场二次确认后放行' },
  { key: 'abnormal_alarm', label: '异常报警', desc: '检测到异常时立即触发报警通知' },
]

/** 区域选项 */
export const ZONE_OPTIONS = [
  '正门大厅', '3F走廊', 'B1机房', '地下车库', '2F会议室', '1F仓库', '全区域',
]
