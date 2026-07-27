/** 设备类型 */
export enum DeviceType {
  Camera = 'camera',
  Sensor = 'sensor',
  Gateway = 'gateway',
  Alarm = 'alarm',
}

/** 设备连接状态 */
export enum DeviceStatus {
  Online = 'online',
  Offline = 'offline',
  Abnormal = 'abnormal',
  Maintenance = 'maintenance',
}

/** 通信协议 */
export enum Protocol {
  WS63 = 'WS63',
  WiFi = 'WiFi',
  BLE = 'BLE',
  Zigbee = 'Zigbee',
}

/** 设备 */
export interface Device {
  id: string
  name: string
  type: DeviceType
  status: DeviceStatus
  protocol: Protocol
  ip: string
  port: number
  location: string
  firmwareVersion: string
  lastHeartbeat: string
  uptime: number
  battery: number
  signalStrength: number
  createdAt: string
  updatedAt: string
}

/** 设备统计 */
export interface DeviceStats {
  total: number
  online: number
  offline: number
  abnormal: number
  maintenance: number
}

/** 设备查询参数 */
export interface DeviceQuery {
  page: number
  pageSize: number
  type?: DeviceType
  status?: DeviceStatus
  keyword?: string
}

/** 设备列表响应 */
export interface DeviceListResponse {
  stats: DeviceStats
  total: number
  list: Device[]
}
