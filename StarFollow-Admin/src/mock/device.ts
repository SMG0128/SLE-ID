import Mock from 'mockjs'
import type { Device, DeviceListResponse } from '@/types/device'
import { DeviceType, DeviceStatus, Protocol } from '@/types/device'

const deviceTypes = Object.values(DeviceType)
const statuses = Object.values(DeviceStatus)
const protocols = Object.values(Protocol)
const locations = ['正门大厅', '3F走廊', 'B1机房', '地下车库', '2F会议室', '1F仓库', '屋顶天台', '配电室']

function randomDevice(): Device {
  const type = deviceTypes[Mock.mock('@integer(0, 3)')]
  return {
    id: Mock.mock('@guid'),
    name: Mock.mock('@ctitle(4, 8)') + '-' + Mock.mock('@string("upper", 3)'),
    type: type as DeviceType,
    status: statuses[Mock.mock('@integer(0, 3)')] as DeviceStatus,
    protocol: protocols[Mock.mock('@integer(0, 3)')] as Protocol,
    ip: Mock.mock('@ip'),
    port: Mock.mock('@integer(8000, 9000)'),
    location: locations[Mock.mock('@integer(0, 7)')],
    firmwareVersion: `v${Mock.mock('@integer(1, 3)')}.${Mock.mock('@integer(0, 9)')}.${Mock.mock('@integer(0, 99)')}`,
    lastHeartbeat: Mock.mock('@datetime("yyyy-MM-dd HH:mm:ss")'),
    uptime: Mock.mock('@integer(1, 720)'),
    battery: Mock.mock('@integer(10, 100)'),
    signalStrength: Mock.mock('@integer(-90, -30)'),
    createdAt: Mock.mock('@datetime("yyyy-MM-dd HH:mm:ss")'),
    updatedAt: Mock.mock('@datetime("yyyy-MM-dd HH:mm:ss")'),
  }
}

export function mockDeviceList(params: Record<string, unknown>): DeviceListResponse {
  const pageSize = (params.pageSize as number) || 10
  const total = Mock.mock('@integer(30, 80)')
  const list: Device[] = []

  for (let i = 0; i < pageSize; i++) {
    list.push(randomDevice())
  }

  return {
    stats: {
      total,
      online: Mock.mock('@integer(20, 50)'),
      offline: Mock.mock('@integer(2, 10)'),
      abnormal: Mock.mock('@integer(1, 5)'),
      maintenance: Mock.mock('@integer(0, 3)'),
    },
    total,
    list,
  }
}
