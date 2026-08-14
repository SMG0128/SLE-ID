import type { SystemSettings, SerialPortOption } from '@/types/system'

const settings: SystemSettings = {
  serial: { port: 'COM3', baudRate: 115200, autoReconnect: true },
  db: { sizeKB: 12845, eventCount: 48213, licenseCount: 4, lastBackup: '2026-08-04 03:00' },
  serverSyncEnabled: false,
  adminName: 'admin',
  adminSecret: '******',
}

/** 获取系统设置 */
export function mockGetSettings(): SystemSettings {
  return { ...settings, serial: { ...settings.serial }, db: { ...settings.db } }
}

/** 更新串口配置 */
export function mockUpdateSerial(config: Partial<SystemSettings['serial']>): SystemSettings['serial'] {
  settings.serial = { ...settings.serial, ...config }
  return { ...settings.serial }
}

/** 更新服务器同步预留配置 */
export function mockUpdateSync(enabled: boolean): void {
  settings.serverSyncEnabled = enabled
}

/** 可用的串口选项 */
export function mockSerialPortOptions(): SerialPortOption[] {
  return [
    { name: 'COM3', desc: 'USB-SERIAL CH340 (WS63-B)' },
    { name: 'COM5', desc: 'USB-SERIAL CP2102' },
    { name: 'COM7', desc: 'USB-SERIAL FT232' },
  ]
}
