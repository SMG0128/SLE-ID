import { mockGetSettings, mockUpdateSerial, mockUpdateSync, mockSerialPortOptions } from '@/mock/system'
import { mockDelay } from './request'
import type { SystemSettings, SerialPortOption } from '@/types/system'

/** 获取系统设置 */
export function getSystemSettings(): Promise<SystemSettings> {
  return mockDelay(mockGetSettings())
}

/** 更新串口配置 */
export function updateSerialConfig(config: Partial<SystemSettings['serial']>): Promise<SystemSettings['serial']> {
  return mockDelay(mockUpdateSerial(config), 100)
}

/** 更新服务器同步预留 */
export function updateServerSync(enabled: boolean): Promise<void> {
  mockUpdateSync(enabled)
  return mockDelay(undefined, 100)
}

/** 获取可用串口列表 */
export function getSerialPortOptions(): Promise<SerialPortOption[]> {
  return mockDelay(mockSerialPortOptions())
}
