/** WS63 检测端设备 */
export interface Device {
  id: string
  name: string
  location: string
  status: '在线' | '离线'
  firmware: string
  heartbeat: number
  usbConnected: boolean
  policyVersion: string
  uptime: string
}

/** 设备列表响应 */
export interface DeviceListResponse {
  total: number
  list: Device[]
}

/** WS63 通信模块状态 */
export interface WS63Status {
  protocol: string
  band: string
  nodes: number
  latency: number
  status: '正常' | '异常'
}
