import Mock from 'mockjs'
import type { AlarmRecord, AlarmListResponse } from '@/types/alarm'
import { AlarmLevel, AlarmHandleStatus } from '@/types/alarm'

const levels = Object.values(AlarmLevel)
const handleStatuses = Object.values(AlarmHandleStatus)
const ruleNames = ['温度过高告警', '湿度异常告警', '震动超阈值', '入侵检测', '设备离线告警']
const deviceNames = ['正门传感器-A1', '走廊传感器-B2', '机房传感器-C3', '停车场传感器-D4', '会议室传感器-E5']

function randomAlarm(): AlarmRecord {
  const level = levels[Mock.mock('@integer(0, 3)')]
  return {
    id: Mock.mock('@guid'),
    ruleId: Mock.mock('@guid'),
    ruleName: ruleNames[Mock.mock('@integer(0, 4)')],
    eventId: Mock.mock('@guid'),
    deviceId: `DEV-${Mock.mock('@string("number", 6)')}`,
    deviceName: deviceNames[Mock.mock('@integer(0, 4)')],
    level: level as AlarmLevel,
    message: Mock.mock('@csentence(10, 25)'),
    value: Mock.mock('@float(0, 120, 1, 2)'),
    threshold: Mock.mock('@float(50, 100, 1, 1)'),
    handler: Mock.mock('@cname'),
    handleStatus: handleStatuses[Mock.mock('@integer(0, 3)')] as AlarmHandleStatus,
    handleNote: Mock.mock('@csentence(5, 15)'),
    handleTime: Mock.mock('@datetime("yyyy-MM-dd HH:mm:ss")'),
    createdAt: Mock.mock('@datetime("yyyy-MM-dd HH:mm:ss")'),
  }
}

export function mockAlarmList(params: Record<string, unknown>): AlarmListResponse {
  const pageSize = (params.pageSize as number) || 10
  const total = Mock.mock('@integer(20, 100)')
  const list: AlarmRecord[] = []

  for (let i = 0; i < pageSize; i++) {
    list.push(randomAlarm())
  }

  return {
    stats: {
      total,
      unconfirmed: Mock.mock('@integer(0, 15)'),
      confirmed: Mock.mock('@integer(0, 20)'),
      processing: Mock.mock('@integer(0, 10)'),
      resolved: Mock.mock('@integer(10, 40)'),
      highUrgent: Mock.mock('@integer(0, 10)'),
      todayNew: Mock.mock('@integer(0, 8)'),
    },
    total,
    list,
  }
}
