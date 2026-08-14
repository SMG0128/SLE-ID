/** 串口配置 */
export interface SerialConfig {
  port: string
  baudRate: number
  autoReconnect: boolean
}

/** 可用的串口选项 */
export interface SerialPortOption {
  name: string
  desc: string
}

/** 数据库信息 */
export interface DatabaseInfo {
  sizeKB: number
  eventCount: number
  licenseCount: number
  lastBackup: string | null
}

/** 系统设置（文档 4.4 系统设置页） */
export interface SystemSettings {
  serial: SerialConfig
  db: DatabaseInfo
  serverSyncEnabled: boolean   // 第二版服务器同步预留
  adminName: string
  adminSecret: string
}

/** 波特率选项 */
export const BAUD_RATE_OPTIONS = [9600, 115200, 230400, 460800, 921600]
