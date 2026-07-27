import Mock from 'mockjs'
import type { SensingEvent, EventListResponse } from '@/types/event'
import { EventType, EventSeverity, EventStatus } from '@/types/event'

const eventTypes = Object.values(EventType)
const severities = Object.values(EventSeverity)
const statuses = Object.values(EventStatus)

const deviceNames = [
  '正门传感器-A1', '走廊传感器-B2', '机房传感器-C3',
  '停车场传感器-D4', '会议室传感器-E5', '仓库传感器-F6',
]
const locations = ['正门大厅', '3F走廊', 'B1机房', '地下车库', '2F会议室', '1F仓库']

function randomEvent(): SensingEvent {
  const id = Mock.mock('@guid')
  const deviceIdx = Mock.mock('@integer(0, 5)')
  const type = eventTypes[Mock.mock('@integer(0, 6)')]
  const severity = severities[Mock.mock('@integer(0, 2)')]
  const status = statuses[Mock.mock('@integer(0, 3)')]

  return {
    id,
    deviceId: `DEV-${Mock.mock('@string("number", 6)')}`,
    deviceName: deviceNames[deviceIdx],
    type: type as EventType,
    severity: severity as EventSeverity,
    status: status as EventStatus,
    title: Mock.mock('@ctitle(6, 16)'),
    description: Mock.mock('@csentence(10, 30)'),
    location: locations[deviceIdx],
    value: Mock.mock('@float(0, 100, 1, 2)'),
    unit: type === EventType.Temperature ? '°C' : type === EventType.Humidity ? '%' : '',
    createdAt: Mock.mock('@datetime("yyyy-MM-dd HH:mm:ss")'),
    updatedAt: Mock.mock('@datetime("yyyy-MM-dd HH:mm:ss")'),
  }
}

export function mockEventList(params: Record<string, unknown>): EventListResponse {
  const pageSize = (params.pageSize as number) || 10
  const total = Mock.mock('@integer(50, 200)')
  const list: SensingEvent[] = []

  for (let i = 0; i < pageSize; i++) {
    list.push(randomEvent())
  }

  return { total, list }
}
