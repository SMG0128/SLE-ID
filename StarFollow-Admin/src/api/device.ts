import { mockDeviceList, mockWS63Status } from '@/mock/device'
import { mockDelay } from './request'
import type { DeviceListResponse, WS63Status } from '@/types/device'

/** 获取设备列表 — page → api → mock */
export function getDeviceList(): Promise<DeviceListResponse> {
  // TODO: 后端就绪 → return request.get('/devices')
  return mockDelay(mockDeviceList())
}

/** 获取 WS63 通信模块状态 */
export function getWS63Status(): Promise<WS63Status> {
  return mockDelay(mockWS63Status())
}

/** 重启设备（发送 WS63 指令） */
export function restartDevice(id: string): Promise<void> {
  // TODO: 后端就绪 → return request.post(`/devices/${id}/restart`)
  return mockDelay(undefined, 100)
}
