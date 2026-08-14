import { EventEmitter } from 'node:events'
import { SerialPort } from 'serialport'
import type { SerialPortOpenOptions } from 'serialport'
import type { SerialConfigRecord } from '../domain.js'
import {
  AckStatus,
  encodeFrame,
  FrameFlag,
  MessageType,
  type ProtocolFrame,
  SourceRole,
  StreamParser,
  writeU32,
} from './protocol.js'

export interface GatewayState {
  connected: boolean
  detectorBReady: boolean
  port: string
  baudRate: number
  autoReconnect: boolean
  lastFrameAt: string | null
  lastHeartbeatAt: string | null
  frameCount: number
  errorCount: number
  lastError: string | null
  lastErrorAt: string | null
  reconnectAttempt: number
  crcErrors: number
  formatErrors: number
  discardedBytes: number
  gatewaySourceId: number | null
  gatewayBootId: number | null
}

export interface PortOption {
  name: string
  desc: string
  vendorId?: string
  productId?: string
}

export class GatewaySerial extends EventEmitter {
  private port: SerialPort | null = null
  private parser = new StreamParser()
  private config: SerialConfigRecord = { port: '', baudRate: 115200, autoReconnect: true }
  private heartbeatTimer: NodeJS.Timeout | null = null
  private reconnectTimer: NodeJS.Timeout | null = null
  private reconnectStep = 0
  private intentionalClose = false
  private messageId = 1
  private readonly state: GatewayState = {
    connected: false,
    detectorBReady: false,
    port: '',
    baudRate: 115200,
    autoReconnect: true,
    lastFrameAt: null,
    lastHeartbeatAt: null,
    frameCount: 0,
    errorCount: 0,
    lastError: null,
    lastErrorAt: null,
    reconnectAttempt: 0,
    crcErrors: 0,
    formatErrors: 0,
    discardedBytes: 0,
    gatewaySourceId: null,
    gatewayBootId: null,
  }

  constructor(
    private readonly hostSourceId: number,
    private readonly hostBootId: number,
  ) {
    super()
  }

  static async listPorts(): Promise<PortOption[]> {
    const ports = await SerialPort.list()
    return ports.map(port => ({
      name: port.path,
      desc: [port.manufacturer, port.serialNumber, port.pnpId].filter(Boolean).join(' · ') || '串口设备',
      vendorId: port.vendorId,
      productId: port.productId,
    }))
  }

  snapshot(): GatewayState {
    return { ...this.state }
  }

  async configure(config: SerialConfigRecord, verifyDetectorB = false): Promise<void> {
    if (config.baudRate !== 115200) throw new Error('Detector B 固定使用 115200 波特率')
    this.config = { ...config }
    this.state.port = config.port
    this.state.baudRate = config.baudRate
    this.state.autoReconnect = config.autoReconnect
    this.reconnectStep = 0
    this.state.reconnectAttempt = 0
    await this.disconnect(true)
    if (config.port) {
      try {
        await this.connect()
      } catch (error) {
        // A saved COM port can be temporarily absent at service startup. Keep
        // retrying in the background, but do not retain a failed UI selection.
        if (config.autoReconnect && !verifyDetectorB) this.scheduleReconnect()
        throw error
      }
      if (verifyDetectorB) {
        try {
          await this.waitForDetectorB(3500)
        } catch (error) {
          await this.disconnect(true)
          throw error
        }
      }
    }
    else this.emitState()
  }

  async connect(): Promise<void> {
    if (!this.config.port || this.port?.isOpen) return
    this.clearReconnect()
    this.intentionalClose = false
    this.parser.reset()
    this.state.detectorBReady = false
    this.state.lastHeartbeatAt = null
    this.state.gatewaySourceId = null
    this.state.gatewayBootId = null
    const options: SerialPortOpenOptions<any> = {
      path: this.config.port,
      baudRate: 115200,
      dataBits: 8,
      stopBits: 1,
      parity: 'none',
      autoOpen: false,
    }
    const port = new SerialPort(options)
    this.port = port
    port.on('data', (data: Buffer) => this.onData(data))
    port.on('error', error => {
      this.noteError(error.message)
      this.closeErroredPort(port)
    })
    port.on('close', () => this.onClose())
    try {
      await new Promise<void>((resolve, reject) => port.open(error => error ? reject(error) : resolve()))
    } catch (error) {
      if (this.port === port) this.port = null
      throw error
    }
    this.state.connected = true
    this.reconnectStep = 0
    this.state.reconnectAttempt = 0
    this.startHeartbeat()
    this.emitState()
  }

  async disconnect(intentional = true): Promise<void> {
    this.intentionalClose = intentional
    this.stopHeartbeat()
    this.clearReconnect()
    const port = this.port
    this.port = null
    if (port?.isOpen) {
      await new Promise<void>(resolve => port.close(() => resolve()))
    }
    this.state.connected = false
    this.state.detectorBReady = false
    this.emitState()
  }

  close(): Promise<void> {
    return this.disconnect(true)
  }

  noteDetectorHeartbeat(frame: ProtocolFrame): void {
    if (frame.sourceRole !== SourceRole.DetectorB) return
    this.state.detectorBReady = true
    this.state.lastHeartbeatAt = new Date().toISOString()
    this.state.gatewaySourceId = frame.sourceId
    this.state.gatewayBootId = frame.bootId
    this.emitState()
  }

  async waitForDetectorB(timeoutMs: number): Promise<void> {
    if (this.state.detectorBReady) return
    await new Promise<void>((resolve, reject) => {
      const onState = (state: GatewayState) => {
        if (state.detectorBReady) finish()
      }
      const timer = setTimeout(() => finish(new Error('当前串口未识别到 Detector B，请确认选择的是 B 板 COM 口且已烧录 Protocol V2 固件')), timeoutMs)
      const finish = (error?: Error) => {
        clearTimeout(timer)
        this.off('state', onState)
        error ? reject(error) : resolve()
      }
      this.on('state', onState)
    })
  }

  send(type: number, payload: Uint8Array = new Uint8Array(), flags = 0, messageId?: number): number {
    const port = this.port
    if (!port?.isOpen) throw new Error('Detector B 串口未连接')
    const assigned = messageId ?? this.nextMessageId()
    const encoded = encodeFrame({
      type,
      flags,
      sourceRole: SourceRole.Host,
      sourceId: this.hostSourceId,
      bootId: this.hostBootId,
      messageId: assigned,
      payload: Buffer.from(payload),
    })
    port.write(encoded, error => {
      if (error) {
        this.noteError(error.message)
        this.closeErroredPort(port)
      }
    })
    return assigned
  }

  sendAck(frame: ProtocolFrame, status: AckStatus): void {
    const payload = Buffer.alloc(5)
    writeU32(payload, 0, frame.messageId)
    payload[4] = status
    this.send(MessageType.Ack, payload, FrameFlag.Response)
  }

  private nextMessageId(): number {
    const value = this.messageId === 0 ? 1 : this.messageId >>> 0
    this.messageId = value === 0xffffffff ? 1 : value + 1
    return value
  }

  private onData(data: Buffer): void {
    const frames = this.parser.push(data)
    this.state.crcErrors = this.parser.crcErrors
    this.state.formatErrors = this.parser.formatErrors
    this.state.discardedBytes = this.parser.discardedBytes
    for (const frame of frames) {
      this.state.lastFrameAt = new Date().toISOString()
      this.state.frameCount += 1
      this.emit('frame', frame)
    }
  }

  private onClose(): void {
    this.stopHeartbeat()
    this.state.connected = false
    this.state.detectorBReady = false
    this.port = null
    this.emitState()
    if (!this.intentionalClose && this.config.autoReconnect && this.config.port) this.scheduleReconnect()
  }

  private startHeartbeat(): void {
    this.stopHeartbeat()
    const tick = () => {
      if (this.state.detectorBReady && this.state.lastHeartbeatAt) {
        const age = Date.now() - Date.parse(this.state.lastHeartbeatAt)
        if (age > 3500) {
          this.state.detectorBReady = false
          this.emitState()
        }
      }
      try {
        this.send(MessageType.Heartbeat)
      } catch {
        // The close/error handler owns reconnection.
      }
    }
    tick()
    this.heartbeatTimer = setInterval(tick, 1000)
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer)
    this.heartbeatTimer = null
  }

  private scheduleReconnect(): void {
    this.clearReconnect()
    const delays = [1000, 2000, 5000, 10000]
    const delay = delays[Math.min(this.reconnectStep, delays.length - 1)]!
    this.reconnectStep += 1
    this.state.reconnectAttempt = this.reconnectStep
    this.emitState()
    this.reconnectTimer = setTimeout(() => {
      void this.connect().catch(error => {
        this.noteError(error instanceof Error ? error.message : String(error))
        this.scheduleReconnect()
      })
    }, delay)
  }

  private clearReconnect(): void {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer)
    this.reconnectTimer = null
  }

  private emitState(): void {
    this.emit('state', this.snapshot())
  }

  private noteError(message: string): void {
    this.state.errorCount += 1
    this.state.lastError = message
    this.state.lastErrorAt = new Date().toISOString()
    this.emit('diagnostic', { level: 'error', message, at: this.state.lastErrorAt })
    this.emitState()
  }

  private closeErroredPort(port: SerialPort): void {
    if (this.port !== port || !port.isOpen) return
    this.port = null
    port.close(() => undefined)
  }
}
