import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit'
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit'
import { constant, manager, scan, ssap } from '@kit.NearLinkKit'
import {
  NearLinkFrame,
  NearLinkMessageType,
  NearLinkProtocol,
  SLEKEY_CONTROL_UUID,
  SLEKEY_DEVICE_INFO_UUID,
  SLEKEY_DEVICE_NAME,
  SLEKEY_SERVICE_UUID,
  SLEKEY_STATUS_UUID
} from './NearLinkProtocol'

const SCAN_DURATION_SECONDS: number = 10
const ACK_TIMEOUT_MS: number = 5000
const NEARLINK_SUPPORT_CHECK_API: number = 23
const ACCESS_NEARLINK_PERMISSION: Permissions = 'ohos.permission.ACCESS_NEARLINK'

const SERVICE_UUID_BYTES: number[] = [
  0x7A, 0x7B, 0x00, 0x01, 0x6D, 0x8F, 0x4A, 0x4E,
  0x9A, 0x5D, 0x53, 0xB7, 0xA1, 0x00, 0x00, 0x01
]

export enum NearLinkConnectionState {
  UNSUPPORTED = 'UNSUPPORTED',
  NEARLINK_OFF = 'NEARLINK_OFF',
  IDLE = 'IDLE',
  SCANNING = 'SCANNING',
  DEVICE_FOUND = 'DEVICE_FOUND',
  CONNECTING = 'CONNECTING',
  CONNECTED = 'CONNECTED',
  HANDSHAKING = 'HANDSHAKING',
  READY = 'READY',
  DISCONNECTING = 'DISCONNECTING',
  DISCONNECTED = 'DISCONNECTED',
  TIMEOUT = 'TIMEOUT',
  ERROR = 'ERROR'
}

export interface NearLinkDevice {
  name: string
  address: string
  rssi: number
  connectable: boolean
}

export interface NearLinkReceivedMessage {
  type: NearLinkMessageType
  sequence: number
  payloadHex: string
}

export type DeviceDiscoveredListener = (devices: NearLinkDevice[]) => void
export type StateChangedListener = (state: NearLinkConnectionState) => void
export type MessageReceivedListener = (message: NearLinkReceivedMessage) => void
export type ErrorListener = (message: string) => void

export class NearLinkConnectionService {
  private static instance: NearLinkConnectionService
  private context: common.UIAbilityContext | null = null
  private client: ssap.Client | null = null
  private controlProperty: ssap.Property | null = null
  private statusProperty: ssap.Property | null = null
  private deviceInfoProperty: ssap.Property | null = null
  private devices: Map<string, NearLinkDevice> = new Map<string, NearLinkDevice>()
  private state: NearLinkConnectionState = NearLinkConnectionState.IDLE
  private scanTimer: number = -1
  private ackTimer: number = -1
  private sequence: number = 0
  private expectedSequence: number = -1
  private expectedType: NearLinkMessageType = NearLinkMessageType.PROTOCOL_ERROR
  private scanListenerRegistered: boolean = false
  private deviceListener: DeviceDiscoveredListener | null = null
  private connectionListener: StateChangedListener | null = null
  private protocolListener: StateChangedListener | null = null
  private messageListener: MessageReceivedListener | null = null
  private errorListener: ErrorListener | null = null

  private readonly handleDeviceFound = (results: Array<scan.ScanResults>): void => {
    let changed: boolean = false
    results.forEach((result: scan.ScanResults) => {
      const normalizedName: string = result.deviceName.split('\u0000').join('').trim()
      const nameMatches: boolean = normalizedName === SLEKEY_DEVICE_NAME
      const serviceMatches: boolean = this.containsServiceUuid(result.data)
      console.info(`[SLEKEY][SCAN_CANDIDATE] name=${normalizedName} address=${result.address} ` +
        `rssi=${result.rssi} connectable=${result.isConnectable} serviceMatch=${serviceMatches}`)
      // API 22 is allowed to return the local name separately from raw advertising data.
      // Accept either advertised identity here, then enforce all Service/Property UUIDs
      // again after the real SSAP connection is established.
      if (!result.isConnectable || (!nameMatches && !serviceMatches)) {
        return
      }
      const device: NearLinkDevice = {
        name: normalizedName.length > 0 ? normalizedName : 'Unknown NearLink device',
        address: result.address,
        rssi: result.rssi,
        connectable: result.isConnectable
      }
      this.devices.set(device.address, device)
      changed = true
      console.info(`[SLEKEY][SCAN] name=${device.name} address=${device.address} rssi=${device.rssi}`)
    })
    if (changed) {
      this.updateState(NearLinkConnectionState.DEVICE_FOUND)
      this.emitDevices()
    }
  }

  private readonly handleConnectionChange = (change: ssap.ConnectionChangeState): void => {
    console.info(`[SLEKEY][CONNECT] address=${change.address} state=${change.state}`)
    if (change.state === constant.ConnectionState.STATE_CONNECTED) {
      this.updateState(NearLinkConnectionState.CONNECTED)
      return
    }
    if (change.state === constant.ConnectionState.STATE_DISCONNECTED) {
      this.clearAckTimer()
      this.releaseClient(false)
      this.reportError('设备主动断开')
      this.updateState(NearLinkConnectionState.DISCONNECTED)
    }
  }

  private readonly handlePropertyChange = (property: ssap.Property): void => {
    if (this.normalizeUuid(property.serviceUuid) !== this.normalizeUuid(SLEKEY_SERVICE_UUID) ||
      this.normalizeUuid(property.propertyUuid) !== this.normalizeUuid(SLEKEY_STATUS_UUID)) {
      return
    }
    this.processFrame(property.value)
  }

  private constructor() {}

  static getInstance(): NearLinkConnectionService {
    if (!NearLinkConnectionService.instance) {
      NearLinkConnectionService.instance = new NearLinkConnectionService()
    }
    return NearLinkConnectionService.instance
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context
  }

  onDeviceDiscovered(listener: DeviceDiscoveredListener | null): void {
    this.deviceListener = listener
  }

  onConnectionStateChanged(listener: StateChangedListener | null): void {
    this.connectionListener = listener
  }

  onProtocolStateChanged(listener: StateChangedListener | null): void {
    this.protocolListener = listener
  }

  onMessageReceived(listener: MessageReceivedListener | null): void {
    this.messageListener = listener
  }

  onError(listener: ErrorListener | null): void {
    this.errorListener = listener
  }

  isNearLinkSupported(): boolean {
    const apiVersion: number = deviceInfo.sdkApiVersion
    if (apiVersion < NEARLINK_SUPPORT_CHECK_API) {
      try {
        // API 13-22 do not expose isNearLinkSupported(). A successful getState()
        // proves that the NearLink core capability is present without bypassing it.
        manager.getState()
        console.info(`[SLEKEY][CAPABILITY] API ${apiVersion}: NearLink getState available`)
        return true
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        if (businessError.code === 801) {
          console.warn(`[SLEKEY][CAPABILITY] API ${apiVersion}: NearLink capability is not supported`)
          return false
        }
        // A transient state-query failure is not proof that the hardware is unsupported.
        // The caller will query the state again and surface the actual operation error.
        console.warn(`[SLEKEY][CAPABILITY] API ${apiVersion}: getState failed, ` +
          `code=${businessError.code}, message=${businessError.message}`)
        return true
      }
    }
    try {
      return manager.isNearLinkSupported()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      console.warn(`[SLEKEY][CAPABILITY] API ${apiVersion}: support check failed, ` +
        `code=${businessError.code}, message=${businessError.message}`)
      return false
    }
  }

  getNearLinkState(): manager.NearlinkState {
    try {
      return manager.getState()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      throw new Error(`读取星闪状态失败（code=${businessError.code}, ` +
        `message=${businessError.message}）`)
    }
  }

  getConnectionState(): NearLinkConnectionState {
    return this.state
  }

  async startScan(): Promise<void> {
    if (!this.isNearLinkSupported()) {
      this.updateState(NearLinkConnectionState.UNSUPPORTED)
      this.reportError('当前设备不支持星闪')
      return
    }
    try {
      if (manager.getState() !== manager.NearlinkState.STATE_ON) {
        this.updateState(NearLinkConnectionState.NEARLINK_OFF)
        this.reportError('星闪未开启，请在系统设置中手动开启')
        return
      }
      if (!await this.ensurePermission()) {
        this.updateState(NearLinkConnectionState.ERROR)
        this.reportError('星闪权限未授予')
        return
      }

      await this.stopScan()
      this.devices.clear()
      this.emitDevices()
      scan.on('deviceFound', this.handleDeviceFound)
      this.scanListenerRegistered = true
      this.updateState(NearLinkConnectionState.SCANNING)
      console.info('[SLEKEY][SCAN] start duration=10s filter=name+app-validated service=7A7B0001')
      // API 22 rejects both an empty filter array and an empty filter object with
      // BusinessError 401. Use the exact device name here, then strictly validate
      // the advertised service UUID and all SSAP services/properties after connect.
      const filters: Array<scan.ScanFilters> = [{ deviceName: SLEKEY_DEVICE_NAME }]
      await scan.startScan(filters, {
        scanMode: scan.ScanMode.SCAN_MODE_BALANCED,
        duration: SCAN_DURATION_SECONDS
      })
      this.scanTimer = setTimeout(() => {
        const found: boolean = this.devices.size > 0
        this.stopScan().then(() => {
          this.updateState(found ? NearLinkConnectionState.DEVICE_FOUND : NearLinkConnectionState.IDLE)
          if (!found) {
            this.reportError('未找到设备')
          }
        })
      }, SCAN_DURATION_SECONDS * 1000)
    } catch (error) {
      await this.stopScan()
      this.updateState(NearLinkConnectionState.ERROR)
      this.reportBusinessError('扫描失败', error as BusinessError)
    }
  }

  async stopScan(): Promise<void> {
    if (this.scanTimer !== -1) {
      clearTimeout(this.scanTimer)
      this.scanTimer = -1
    }
    try {
      if (this.state === NearLinkConnectionState.SCANNING ||
        this.state === NearLinkConnectionState.DEVICE_FOUND) {
        await scan.stopScan()
      }
    } catch (error) {
      console.warn(`[SLEKEY][SCAN] stop failed: ${JSON.stringify(error)}`)
    }
    if (this.scanListenerRegistered) {
      try {
        scan.off('deviceFound', this.handleDeviceFound)
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        console.warn(`[SLEKEY][SCAN] listener cleanup failed, ` +
          `code=${businessError.code}, message=${businessError.message}`)
      }
      this.scanListenerRegistered = false
    }
  }

  async connect(device: NearLinkDevice): Promise<void> {
    await this.stopScan()
    await this.disconnect()
    this.updateState(NearLinkConnectionState.CONNECTING)
    console.info(`[SLEKEY][CONNECT] connecting address=${device.address}`)
    try {
      this.client = ssap.createClient(device.address)
      this.client.on('connectionStateChange', this.handleConnectionChange)
      this.client.on('propertyChange', this.handlePropertyChange)
      await this.client.connect()
      this.updateState(NearLinkConnectionState.CONNECTED)
      await this.prepareService()
      await this.sendHello()
    } catch (error) {
      this.releaseClient(true)
      this.updateState(NearLinkConnectionState.ERROR)
      this.reportBusinessError('连接被拒绝或连接失败', error as BusinessError)
    }
  }

  async disconnect(): Promise<void> {
    await this.stopScan()
    this.clearAckTimer()
    if (!this.client) {
      this.updateState(NearLinkConnectionState.DISCONNECTED)
      return
    }
    this.updateState(NearLinkConnectionState.DISCONNECTING)
    const oldClient: ssap.Client = this.client
    try {
      if (this.statusProperty) {
        await oldClient.setPropertyNotification(this.statusProperty, false)
      }
      await oldClient.disconnect()
    } catch (error) {
      console.warn(`[SLEKEY][DISCONNECT] ${JSON.stringify(error)}`)
    }
    this.releaseClient(false)
    this.updateState(NearLinkConnectionState.DISCONNECTED)
  }

  async sendHello(): Promise<void> {
    await this.sendRequest(NearLinkMessageType.HELLO, NearLinkMessageType.HELLO_ACK)
  }

  async sendPing(): Promise<void> {
    await this.sendRequest(NearLinkMessageType.PING, NearLinkMessageType.PONG)
  }

  async readDeviceInfo(): Promise<void> {
    if (!this.client || !this.deviceInfoProperty) {
      this.reportError('服务不匹配：设备信息属性不可用')
      return
    }
    try {
      const property: ssap.Property = await this.client.readProperty(this.deviceInfoProperty)
      const frame: NearLinkFrame = NearLinkProtocol.decode(property.value)
      if (frame.type !== NearLinkMessageType.DEVICE_INFO) {
        throw new Error(`unexpected device info type: 0x${frame.type.toString(16)}`)
      }
      this.emitMessage(frame)
    } catch (error) {
      this.reportBusinessError('读取设备信息失败', error as BusinessError)
    }
  }

  async dispose(): Promise<void> {
    await this.stopScan()
    await this.disconnect()
    this.clearAckTimer()
    this.deviceListener = null
    this.connectionListener = null
    this.protocolListener = null
    this.messageListener = null
    this.errorListener = null
  }

  private async prepareService(): Promise<void> {
    if (!this.client) {
      throw new Error('SSAP client is unavailable')
    }
    let services: Array<ssap.Service> = []
    try {
      services = await this.client.getServices()
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      throw new Error(`服务发现失败（code=${businessError.code}, ` +
        `message=${businessError.message}）`)
    }
    let targetService: ssap.Service | null = null
    for (let index: number = 0; index < services.length; index++) {
      const service: ssap.Service = services[index]
      console.info(`[SLEKEY][SERVICE] discovered ${service.serviceUuid}`)
      if (this.normalizeUuid(service.serviceUuid) === this.normalizeUuid(SLEKEY_SERVICE_UUID)) {
        targetService = service
      }
    }
    if (!targetService) {
      throw new Error('服务不匹配')
    }

    targetService.properties.forEach((property: ssap.Property) => {
      const uuid: string = this.normalizeUuid(property.propertyUuid)
      console.info(`[SLEKEY][SERVICE] property=${property.propertyUuid} operation=${property.operation}`)
      if (uuid === this.normalizeUuid(SLEKEY_CONTROL_UUID)) {
        this.controlProperty = property
      } else if (uuid === this.normalizeUuid(SLEKEY_STATUS_UUID)) {
        this.statusProperty = property
      } else if (uuid === this.normalizeUuid(SLEKEY_DEVICE_INFO_UUID)) {
        this.deviceInfoProperty = property
      }
    })
    if (!this.controlProperty || !this.statusProperty || !this.deviceInfoProperty) {
      throw new Error('服务不匹配：缺少控制、状态或设备信息属性')
    }
    const controlProperty: ssap.Property = this.controlProperty
    const statusProperty: ssap.Property = this.statusProperty
    const deviceInfoProperty: ssap.Property = this.deviceInfoProperty
    if (!this.hasOperation(controlProperty, ssap.Operation.WRITE_WITH_RESPONSE)) {
      throw new Error('服务权限不匹配：控制属性不支持带响应写入')
    }
    if (!this.hasOperation(statusProperty, ssap.Operation.NOTIFY) ||
      !this.hasClientConfigurationDescriptor(statusProperty)) {
      throw new Error('服务权限不匹配：状态属性缺少 Notify 或客户端配置描述符')
    }
    if (!this.hasOperation(deviceInfoProperty, ssap.Operation.READABLE)) {
      throw new Error('服务权限不匹配：设备信息属性不可读')
    }
    try {
      await this.client.setPropertyNotification(this.statusProperty, true)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      throw new Error(`启用状态通知失败（code=${businessError.code}, ` +
        `message=${businessError.message}）`)
    }
  }

  private hasOperation(property: ssap.Property, operation: ssap.Operation): boolean {
    return property.operation !== undefined && (property.operation & operation) === operation
  }

  private hasClientConfigurationDescriptor(property: ssap.Property): boolean {
    if (!property.descriptors) {
      return false
    }
    for (let index: number = 0; index < property.descriptors.length; index++) {
      if (property.descriptors[index].descriptorType === ssap.PropertyDescriptorType.CLIENT_PROPERTY_CONFIG) {
        return true
      }
    }
    return false
  }

  private async sendRequest(type: NearLinkMessageType, expectedType: NearLinkMessageType): Promise<void> {
    if (!this.client || !this.controlProperty) {
      this.reportError('写入失败：尚未建立可用 SSAP 连接')
      return
    }
    this.sequence = (this.sequence + 1) & 0xFFFF
    this.expectedSequence = this.sequence
    this.expectedType = expectedType
    this.updateState(NearLinkConnectionState.HANDSHAKING)
    try {
      const controlProperty: ssap.Property = this.controlProperty
      const request: ssap.Property = {
        serviceUuid: controlProperty.serviceUuid,
        propertyUuid: controlProperty.propertyUuid,
        value: NearLinkProtocol.encode(type, this.sequence)
      }
      console.info(`[SLEKEY][TX] type=0x${type.toString(16)} seq=${this.sequence} len=0`)
      // Start the timeout before WRITE. A fast server may notify HELLO_ACK/PONG
      // before writeProperty() resolves; starting it afterwards leaves a stale timer.
      this.startAckTimer()
      await this.client.writeProperty(request, ssap.PropertyWriteType.WRITE)
    } catch (error) {
      this.clearAckTimer()
      this.updateState(NearLinkConnectionState.ERROR)
      this.reportBusinessError('写入失败', error as BusinessError)
    }
  }

  private processFrame(buffer: ArrayBuffer): void {
    try {
      const frame: NearLinkFrame = NearLinkProtocol.decode(buffer)
      console.info(`[SLEKEY][RX] type=0x${frame.type.toString(16)} seq=${frame.sequence} len=${frame.payload.byteLength}`)
      this.emitMessage(frame)
      if (frame.type >= NearLinkMessageType.PROTOCOL_ERROR) {
        throw new Error(`设备返回协议错误 0x${frame.type.toString(16)}`)
      }
      if (frame.sequence !== this.expectedSequence) {
        throw new Error(`sequence mismatch: expected ${this.expectedSequence}, received ${frame.sequence}`)
      }
      if (frame.type !== this.expectedType) {
        throw new Error(`message type mismatch: expected 0x${this.expectedType.toString(16)}, received 0x${frame.type.toString(16)}`)
      }
      this.clearAckTimer()
      this.updateState(NearLinkConnectionState.READY)
    } catch (error) {
      this.clearAckTimer()
      this.updateState(NearLinkConnectionState.ERROR)
      const message: string = `${error}`
      this.reportError(message.indexOf('CRC') >= 0 ? `CRC 错误：${message}` : `回执校验失败：${message}`)
    }
  }

  private async ensurePermission(): Promise<boolean> {
    if (!this.context) {
      return false
    }
    const managerInstance: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
    try {
      const result: PermissionRequestResult = await managerInstance.requestPermissionsFromUser(
        this.context, [ACCESS_NEARLINK_PERMISSION])
      return result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (error) {
      this.reportBusinessError('请求星闪权限失败', error as BusinessError)
      return false
    }
  }

  private containsServiceUuid(buffer: ArrayBuffer): boolean {
    const bytes: Uint8Array = new Uint8Array(buffer)
    let offset: number = 0
    while (offset < bytes.byteLength) {
      const fieldLength: number = bytes[offset]
      if (fieldLength === 0 || offset + fieldLength >= bytes.byteLength) {
        break
      }
      const type: number = bytes[offset + 1]
      if ((type === 0x04 || type === 0x06 || type === 0x08) && fieldLength >= 17 &&
        this.matchesUuid(bytes, offset + 2)) {
        return true
      }
      offset += fieldLength + 1
    }
    return false
  }

  private matchesUuid(bytes: Uint8Array, offset: number): boolean {
    let canonical: boolean = true
    let reversed: boolean = true
    for (let index: number = 0; index < SERVICE_UUID_BYTES.length; index++) {
      canonical = canonical && bytes[offset + index] === SERVICE_UUID_BYTES[index]
      reversed = reversed && bytes[offset + index] === SERVICE_UUID_BYTES[SERVICE_UUID_BYTES.length - 1 - index]
    }
    return canonical || reversed
  }

  private normalizeUuid(uuid: string): string {
    return uuid.split('-').join('').toUpperCase()
  }

  private updateState(state: NearLinkConnectionState): void {
    this.state = state
    if (this.connectionListener) {
      this.connectionListener(state)
    }
    if (this.protocolListener && (state === NearLinkConnectionState.HANDSHAKING ||
      state === NearLinkConnectionState.READY || state === NearLinkConnectionState.ERROR ||
      state === NearLinkConnectionState.TIMEOUT)) {
      this.protocolListener(state)
    }
  }

  private emitDevices(): void {
    if (this.deviceListener) {
      this.deviceListener(Array.from(this.devices.values()))
    }
  }

  private emitMessage(frame: NearLinkFrame): void {
    if (this.messageListener) {
      this.messageListener({
        type: frame.type,
        sequence: frame.sequence,
        payloadHex: NearLinkProtocol.hex(frame.payload)
      })
    }
  }

  private startAckTimer(): void {
    this.clearAckTimer()
    this.ackTimer = setTimeout(() => {
      this.updateState(NearLinkConnectionState.TIMEOUT)
      this.reportError('回执超时')
    }, ACK_TIMEOUT_MS)
  }

  private clearAckTimer(): void {
    if (this.ackTimer !== -1) {
      clearTimeout(this.ackTimer)
      this.ackTimer = -1
    }
  }

  private releaseClient(closeClient: boolean): void {
    if (this.client) {
      try {
        this.client.off('propertyChange', this.handlePropertyChange)
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        console.warn(`[SLEKEY][CLIENT] property listener cleanup failed, ` +
          `code=${businessError.code}, message=${businessError.message}`)
      }
      try {
        this.client.off('connectionStateChange', this.handleConnectionChange)
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        console.warn(`[SLEKEY][CLIENT] connection listener cleanup failed, ` +
          `code=${businessError.code}, message=${businessError.message}`)
      }
      try {
        this.client.close()
      } catch (error) {
        if (closeClient) {
          console.warn(`[SLEKEY][CLIENT] close failed: ${JSON.stringify(error)}`)
        }
      }
    }
    this.client = null
    this.controlProperty = null
    this.statusProperty = null
    this.deviceInfoProperty = null
  }

  private reportBusinessError(prefix: string, error: BusinessError): void {
    if (error.code === undefined) {
      this.reportError(`${prefix}（${error.message}）`)
      return
    }
    this.reportError(`${prefix}（code=${error.code}, message=${error.message}）`)
  }

  private reportError(message: string): void {
    console.error(`[SLEKEY][ERROR] ${message}`)
    if (this.errorListener) {
      this.errorListener(message)
    }
  }
}
