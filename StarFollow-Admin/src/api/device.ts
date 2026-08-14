import request from './request'
import type { DeviceListResponse, WS63Status, SerialStatus } from '@/types/device'

/** 获取设备列表 */
export function getDeviceList(): Promise<DeviceListResponse> {
  return request.get<never, DeviceListResponse>('/devices')
}

/** 获取 WS63 通信模块状态 */
export function getWS63Status(): Promise<WS63Status> {
  return request.get<never, WS63Status>('/devices/ws63-status')
}

/** 获取 USB 串口状态 */
export function getSerialStatus(): Promise<SerialStatus> {
  return request.get<never, SerialStatus>('/devices/serial-status')
}

/** 重启设备（发送 WS63 指令） */
export function restartDevice(id: string): Promise<void> {
  return request.post<never, void>(`/devices/${encodeURIComponent(id)}/restart`)
}
