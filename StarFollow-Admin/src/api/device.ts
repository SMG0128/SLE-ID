import request from './request'
import type { DeviceQuery, DeviceListResponse, Device } from '@/types/device'

/** 获取设备列表 */
export function getDeviceList(params: DeviceQuery): Promise<DeviceListResponse> {
  return request({ url: '/devices', method: 'get', params })
}

/** 获取设备详情 */
export function getDeviceDetail(id: string): Promise<Device> {
  return request({ url: `/devices/${id}`, method: 'get' })
}

/** 重启设备 */
export function restartDevice(id: string): Promise<void> {
  return request({ url: `/devices/${id}/restart`, method: 'post' })
}

/** 更新设备固件 */
export function updateFirmware(id: string, version: string): Promise<void> {
  return request({ url: `/devices/${id}/firmware`, method: 'post', data: { version } })
}
