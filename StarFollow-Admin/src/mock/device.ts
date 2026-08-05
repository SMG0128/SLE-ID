import type { Device, DeviceListResponse, WS63Status, SerialStatus } from '@/types/device'

const devices: Device[] = [
  { id: 'DEV-001', name: '正门检测端', location: '正门大厅', status: '在线', firmware: 'v3.2.1', heartbeat: 5, usbConnected: true, policyVersion: 'POL-2.4', uptime: '15天' },
  { id: 'DEV-002', name: '走廊检测端', location: '3F走廊', status: '在线', firmware: 'v3.2.1', heartbeat: 8, usbConnected: true, policyVersion: 'POL-2.4', uptime: '15天' },
  { id: 'DEV-003', name: '机房检测端', location: 'B1机房', status: '在线', firmware: 'v3.2.0', heartbeat: 6, usbConnected: false, policyVersion: 'POL-2.3', uptime: '12天' },
  { id: 'DEV-004', name: '车库检测端', location: '地下车库', status: '在线', firmware: 'v3.2.1', heartbeat: 4, usbConnected: true, policyVersion: 'POL-2.4', uptime: '15天' },
  { id: 'DEV-005', name: '会议室检测端', location: '2F会议室', status: '离线', firmware: 'v3.1.9', heartbeat: 0, usbConnected: false, policyVersion: 'POL-2.2', uptime: '-' },
  { id: 'DEV-006', name: '仓库检测端', location: '1F仓库', status: '在线', firmware: 'v3.2.1', heartbeat: 9, usbConnected: true, policyVersion: 'POL-2.4', uptime: '15天' },
]

/** 获取设备列表 */
export function mockDeviceList(): DeviceListResponse {
  return { total: devices.length, list: [...devices] }
}

/** 获取 WS63 通信模块状态 */
export function mockWS63Status(): WS63Status {
  return { protocol: 'WS63 v2.4', band: '2.4GHz', nodes: 6, latency: 12, status: '正常' }
}

/** 获取 USB 串口状态 */
export function mockSerialStatus(): SerialStatus {
  return { connected: true, port: 'COM3', baudRate: 115200, autoReconnect: true, lastFrameAt: '2026-08-05 16:58:12', frameCount: 48213, errorCount: 3 }
}
