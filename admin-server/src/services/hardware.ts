import { createHash } from 'node:crypto'
import type { StarFollowDatabase } from '../db.js'
import {
  alarmFor,
  eventResult,
  eventStatus,
  formatEventKey,
  type HardwareConfirmation,
  type HardwareEvent,
  type HardwareHeartbeat,
} from '../domain.js'
import { ApiError } from '../http.js'
import type { WsHub } from '../ws/hub.js'
import { GatewaySerial } from '../ws63/gateway.js'
import {
  AckStatus,
  FrameFlag,
  MessageType,
  type ProtocolFrame,
  readU32,
  SourceRole,
  writeU32,
} from '../ws63/protocol.js'

interface PendingCommand {
  dbCommandId: number
  requestId: number
  commandType: number
  payload: Buffer
  attempts: number
  maxAttempts: number
  timeoutMs: number
  timer: NodeJS.Timeout | null
  resolve: (value: CommandResult) => void
  reject: (error: Error) => void
}

export interface CommandResult {
  requestId: number
  status: number
  resultValue: number
  attempts: number
}

export class HardwareService {
  private hub: WsHub | null = null
  private chain = Promise.resolve()
  private readonly pending = new Map<string, PendingCommand>()

  constructor(
    readonly gateway: GatewaySerial,
    private readonly db: StarFollowDatabase,
  ) {
    gateway.on('frame', frame => {
      this.chain = this.chain.then(() => this.handleFrame(frame as ProtocolFrame)).catch(error => {
        console.error('[hardware] frame handling failed', error)
      })
    })
    gateway.on('state', state => this.hub?.broadcast('serial.status', state))
  }

  attachHub(hub: WsHub): void {
    this.hub = hub
  }

  async start(): Promise<void> {
    const config = this.db.getSetting<any>('serial') ?? { port: '', baudRate: 115200, autoReconnect: true }
    if (config.port) {
      try {
        await this.gateway.configure(config)
      } catch (error) {
        console.warn('[hardware] initial serial connection failed:', error instanceof Error ? error.message : error)
      }
    }
  }

  async stop(): Promise<void> {
    for (const command of this.pending.values()) {
      if (command.timer) clearTimeout(command.timer)
      command.reject(new Error('server shutdown'))
    }
    this.pending.clear()
    await this.gateway.close()
  }

  async deployPolicy(license: any, organizationId: number, operator = 'system'): Promise<Record<string, unknown>> {
    this.requireReady()
    const policies = license.policies ?? {}
    let flags = 0
    if (policies.allowExecute) flags |= 0x0001
    if (policies.forceConfirm) flags |= 0x0002
    if (policies.userConfirm) flags |= 0x0004
    if (policies.offlineAllowed) flags |= 0x0008
    if (policies.unauthorizedAction === 'alarm') flags |= 0x0010
    const requestId = this.db.nextRequestId()
    // Detector B keeps one active policy, so versions must be globally monotonic,
    // rather than restarting from 1 for every license record.
    const policyVersion = this.db.nextPolicyVersion()
    const payload = Buffer.alloc(20)
    writeU32(payload, 0, requestId)
    writeU32(payload, 4, Number(license.hardwarePermissionId))
    writeU32(payload, 8, policyVersion)
    writeU32(payload, 12, organizationId)
    payload.writeUInt16LE(flags, 16)
    this.db.recordAudit('policy.deploy.requested', 'license', String(license.id), operator, {
      requestId,
      policyVersion,
      organizationId,
      hardwareFlags: flags,
    })
    try {
      const result = await this.sendCommand(MessageType.PolicySync, requestId, payload, 3, 1500)
      this.db.markLicenseDeployment(String(license.id), policyVersion, result.status === 0 ? 'synced' : 'failed')
      this.db.recordAudit('policy.deploy.completed', 'license', String(license.id), operator, result)
      this.hub?.broadcast('policy.result', { licenseId: license.id, policyVersion, ...result })
      return {
        licenseId: license.id,
        policyVersion,
        status: result.status,
        attempts: result.attempts,
        capability: license.capability,
        hardwareFlags: flags,
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      this.db.markLicenseDeployment(String(license.id), policyVersion, 'failed')
      this.db.recordAudit('policy.deploy.failed', 'license', String(license.id), operator, { requestId, policyVersion, error: message })
      this.hub?.broadcast('policy.result', { licenseId: license.id, policyVersion, requestId, failed: true, error: message })
      throw error
    }
  }

  async decideConfirmation(id: string, decision: 'approve' | 'reject', operator = 'system'): Promise<Record<string, unknown>> {
    this.requireReady()
    const claim = this.db.claimConfirmation(id, decision)
    if (!claim) throw new ApiError(409, 2202, '确认不存在、已处理或已过期')
    const payload = Buffer.alloc(9)
    writeU32(payload, 0, claim.requestId)
    writeU32(payload, 4, claim.eventId)
    payload[8] = claim.result
    this.db.recordAudit('confirmation.decision.requested', 'confirmation', id, operator, {
      decision,
      requestId: claim.requestId,
      eventId: claim.eventId,
    })
    try {
      const result = await this.sendCommand(MessageType.ConfirmResult, claim.requestId, payload, 2, 1000)
      const success = result.status === 0
      this.db.finishConfirmation(id, success, success ? undefined : `status=${result.status}`)
      this.db.recordAudit('confirmation.decision.completed', 'confirmation', id, operator, { decision, success, ...result })
      const response = { id, decision, success, ...result }
      this.hub?.broadcast('confirmation.resolved', response)
      return response
    } catch (error) {
      this.db.finishConfirmation(id, false, error instanceof Error ? error.message : String(error))
      this.db.recordAudit('confirmation.decision.failed', 'confirmation', id, operator, {
        decision,
        error: error instanceof Error ? error.message : String(error),
      })
      throw error
    }
  }

  private async handleFrame(frame: ProtocolFrame): Promise<void> {
    if (frame.sourceRole !== SourceRole.DetectorB) return
    switch (frame.type) {
      case MessageType.Heartbeat:
        this.handleHeartbeat(frame)
        return
      case MessageType.EventReport:
      case MessageType.AlertReport:
        this.handleEvent(frame, frame.type === MessageType.AlertReport)
        return
      case MessageType.ConfirmRequest:
        this.handleConfirmation(frame)
        return
      case MessageType.PolicyResult:
        this.handlePolicyResult(frame)
        return
      case MessageType.CommandResult:
        this.handleCommandResult(frame)
        return
      default:
        if ((frame.flags & FrameFlag.AckRequired) !== 0) this.gateway.sendAck(frame, AckStatus.BadMessage)
    }
  }

  private handleHeartbeat(frame: ProtocolFrame): void {
    if (frame.payload.length !== 20) return
    const heartbeat: HardwareHeartbeat = {
      gatewaySourceId: frame.sourceId,
      gatewayBootId: frame.bootId,
      uptimeMs: readU32(frame.payload, 0),
      firmwareVersion: readU32(frame.payload, 4),
      policyVersion: readU32(frame.payload, 8),
      queueDepth: frame.payload[12] ?? 0,
      hostOnline: (frame.payload[13] ?? 0) !== 0,
      queueOverflows: frame.payload.readUInt16LE(14),
      framesSent: readU32(frame.payload, 16),
      receivedAt: new Date().toISOString(),
    }
    this.db.upsertHeartbeat(heartbeat)
    this.gateway.noteDetectorHeartbeat(frame)
    const device = this.db.getDevices().find(item => Number(item.sourceId) === frame.sourceId)
    if (device) this.hub?.broadcast('device.upsert', { ...device, usbConnected: true })
  }

  private handleEvent(frame: ProtocolFrame, alert: boolean): void {
    if (frame.payload.length !== 40) {
      if ((frame.flags & FrameFlag.AckRequired) !== 0) this.gateway.sendAck(frame, AckStatus.BadMessage)
      return
    }
    const event: HardwareEvent = {
      eventId: readU32(frame.payload, 0),
      sourceId: readU32(frame.payload, 4),
      bootId: readU32(frame.payload, 8),
      cardAnonId: readU32(frame.payload, 12),
      permissionId: readU32(frame.payload, 16),
      timestampMs: readU32(frame.payload, 20),
      direction: frame.payload[24] ?? 0,
      auth: frame.payload[25] ?? 0,
      action: frame.payload[26] ?? 0,
      confirm: frame.payload[27] ?? 0,
      execution: frame.payload[28] ?? 0,
      reason: frame.payload[29] ?? 0,
      distanceCm: frame.payload.readUInt16LE(30),
      confidence: frame.payload[32] ?? 0,
      state: frame.payload[33] ?? 0,
      decisionTimestampMs: readU32(frame.payload, 34),
      result: '待定',
      status: '',
      eventKey: '',
      receivedAt: new Date().toISOString(),
    }
    event.eventKey = formatEventKey(event.sourceId, event.bootId, event.eventId)
    event.result = eventResult(event.auth, event.confirm, event.execution, event.reason)
    event.status = eventStatus(event.action, event.confirm, event.execution, event.reason)
    const identity = { sourceId: frame.sourceId, bootId: frame.bootId, messageId: frame.messageId, type: frame.type, receivedAt: event.receivedAt }
    const result = this.db.ingestEventFrame(identity, event, alert ? alarmFor(event.reason, event.execution) : null)
    if ((frame.flags & FrameFlag.AckRequired) !== 0) {
      this.gateway.sendAck(frame, result.duplicateFrame ? AckStatus.Duplicate : AckStatus.Accepted)
    }
    if (!result.duplicateFrame) {
      this.hub?.broadcast('event.upsert', { eventKey: event.eventKey, result: event.result, status: event.status })
      if (result.value?.alarmId) this.hub?.broadcast('alarm.created', { id: result.value.alarmId, eventKey: event.eventKey })
    }
  }

  private handleConfirmation(frame: ProtocolFrame): void {
    if (frame.payload.length !== 24) {
      if ((frame.flags & FrameFlag.AckRequired) !== 0) this.gateway.sendAck(frame, AckStatus.BadMessage)
      return
    }
    const receivedAt = new Date()
    const confirmation: HardwareConfirmation = {
      gatewaySourceId: frame.sourceId,
      gatewayBootId: frame.bootId,
      requestId: readU32(frame.payload, 0),
      eventId: readU32(frame.payload, 4),
      cardAnonId: readU32(frame.payload, 8),
      permissionId: readU32(frame.payload, 12),
      deviceTimestampMs: readU32(frame.payload, 16),
      action: frame.payload[20] ?? 0,
      direction: frame.payload[21] ?? 0,
      expiresAt: new Date(receivedAt.getTime() + 9000).toISOString(),
      receivedAt: receivedAt.toISOString(),
    }
    const identity = { sourceId: frame.sourceId, bootId: frame.bootId, messageId: frame.messageId, type: frame.type, receivedAt: confirmation.receivedAt }
    const result = this.db.ingestConfirmationFrame(identity, confirmation)
    if ((frame.flags & FrameFlag.AckRequired) !== 0) {
      this.gateway.sendAck(frame, result.duplicateFrame ? AckStatus.Duplicate : AckStatus.Accepted)
    }
    if (!result.duplicateFrame && result.value) this.hub?.broadcast('confirmation.pending', result.value)
  }

  private handlePolicyResult(frame: ProtocolFrame): void {
    if (frame.payload.length !== 9) return
    const requestId = readU32(frame.payload, 0)
    this.resolveCommand(MessageType.PolicySync, {
      requestId,
      status: frame.payload[4] ?? 2,
      resultValue: readU32(frame.payload, 5),
      attempts: 0,
    })
  }

  private handleCommandResult(frame: ProtocolFrame): void {
    if (frame.payload.length !== 10) return
    const requestId = readU32(frame.payload, 0)
    const commandType = frame.payload[4] ?? 0
    this.resolveCommand(commandType, {
      requestId,
      status: frame.payload[5] ?? 2,
      resultValue: readU32(frame.payload, 6),
      attempts: 0,
    })
  }

  private sendCommand(commandType: number, requestId: number, payload: Buffer, maxAttempts: number, timeoutMs: number): Promise<CommandResult> {
    const key = this.pendingKey(commandType, requestId)
    if (this.pending.has(key)) throw new ApiError(409, 2102, 'requestId 命令冲突')
    const payloadHash = createHash('sha256').update(payload).digest('hex')
    const dbCommandId = this.db.recordCommand(requestId, commandType, payloadHash, this.gateway.snapshot().gatewaySourceId)
    return new Promise<CommandResult>((resolve, reject) => {
      const pending: PendingCommand = { dbCommandId, requestId, commandType, payload, attempts: 0, maxAttempts, timeoutMs, timer: null, resolve, reject }
      this.pending.set(key, pending)
      this.transmitPending(pending)
    })
  }

  private transmitPending(pending: PendingCommand): void {
    pending.attempts += 1
    const flags = pending.attempts > 1 ? FrameFlag.Retry : 0
    try {
      this.gateway.send(pending.commandType, pending.payload, flags)
    } catch (error) {
      if (pending.attempts < pending.maxAttempts) {
        pending.timer = setTimeout(() => this.transmitPending(pending), pending.timeoutMs)
      } else {
        this.failPending(pending, error instanceof Error ? error : new Error(String(error)))
      }
      return
    }
    pending.timer = setTimeout(() => {
      if (pending.attempts < pending.maxAttempts) {
        this.transmitPending(pending)
      } else {
        this.failPending(pending, new ApiError(504, 2101, '硬件命令等待回执超时'))
      }
    }, pending.timeoutMs)
  }

  private resolveCommand(commandType: number, result: CommandResult): void {
    const key = this.pendingKey(commandType, result.requestId)
    const pending = this.pending.get(key)
    if (!pending) return
    if (pending.timer) clearTimeout(pending.timer)
    this.pending.delete(key)
    result.attempts = pending.attempts
    this.db.updateCommand(pending.dbCommandId, result.status === 0 ? 'success' : 'rejected', pending.attempts, result.status, result.resultValue)
    pending.resolve(result)
  }

  private failPending(pending: PendingCommand, error: Error): void {
    if (pending.timer) clearTimeout(pending.timer)
    this.pending.delete(this.pendingKey(pending.commandType, pending.requestId))
    this.db.updateCommand(pending.dbCommandId, 'failed', pending.attempts, undefined, undefined, error.message)
    pending.reject(error)
  }

  private pendingKey(commandType: number, requestId: number): string {
    return `${commandType}:${requestId >>> 0}`
  }

  private requireReady(): void {
    const state = this.gateway.snapshot()
    if (!state.connected) throw new ApiError(503, 2001, 'Detector B 串口未连接')
    if (!state.detectorBReady) throw new ApiError(503, 2002, '当前串口尚未识别到 Detector B')
  }
}
