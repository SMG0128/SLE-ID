import request from './request'
import type { SystemSettings, SerialPortOption } from '@/types/system'

/** 获取系统设置 */
export function getSystemSettings(): Promise<SystemSettings> {
  return request.get<never, SystemSettings>('/system/settings')
}

/** 更新串口配置 */
export function updateSerialConfig(config: Partial<SystemSettings['serial']>): Promise<SystemSettings['serial']> {
  return request.patch<never, SystemSettings['serial']>('/system/serial', config)
}

/** 更新服务器同步预留 */
export function updateServerSync(enabled: boolean): Promise<void> {
  return request.patch<never, void>('/system/server-sync', { enabled })
}

/** 获取可用串口列表 */
export function getSerialPortOptions(): Promise<SerialPortOption[]> {
  return request.get<never, SerialPortOption[]>('/system/serial-ports')
}

export function backupDatabase(): Promise<Record<string, unknown>> {
  return request.post<never, Record<string, unknown>>('/system/backup')
}
