import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit'
import { constant, manager, scan, ssap } from '@kit.NearLinkKit'
import { CardSleClient } from './CardSleClient'
import {
  CardCInfo,
  CardCommitAcknowledgement,
  CardCredentialReadback,
  CardWriteAuthorization,
  CardWritePackage,
  CardWriteTarget
} from '../models/CardProvisioning'
import {
  CARD_C_COMMAND_UUID,
  CARD_C_DEVICE_NAME,
  CARD_C_INFO_UUID,
  CARD_C_MAX_CHUNK_BYTES,
  CARD_C_RESPONSE_UUID,
  CARD_C_SERVICE_UUID,
  CardCFrame,
  CardCMessageType,
  CardCProtocol
} from './CardCProtocol'
import { PhysicalCardService } from './PhysicalCardService'
import { CredentialService } from './CredentialService'
import {
  CredentialRemovalResult,
  CredentialWriteProgressListener,
  CredentialWriteRequest,
  CredentialWriteResult,
  PhysicalCardConnectionResult,
  PhysicalCardDiscoveryListener,
  PhysicalCardFailureReason,
  PrimaryPhysicalCardBindingResult
} from '../models/PhysicalCardOperation'
import {
  MockPhysicalCardFailureMode,
  PhysicalCard,
  PhysicalCardConnectionState,
  PhysicalCardDiscoveryState,
  PhysicalCardStatus
} from '../models/PhysicalCard'
import { Credential, CredentialBindingStatus } from '../models/Credential'
import { Authorization } from '../models/Authorization'
import { OperationAuthority, OperationState } from '../models/Operation'

const ACCESS_NEARLINK_PERMISSION: Permissions = 'ohos.permission.ACCESS_NEARLINK'
const SCAN_TIMEOUT_MS: number = 10000
const RESPONSE_TIMEOUT_MS: number = 5000

interface PendingResponse {
  requestId: number
  commandType: number
  listItems: CardCFrame[]
  resolve: (frames: CardCFrame[]) => void
  reject: (error: Error) => void
  timer: number
}

export class CardCSleAdapter implements
  CardSleClient,
  PhysicalCardService,
  CredentialService {
  private readonly context: common.UIAbilityContext
  private client: ssap.Client | null = null
  private infoProperty: ssap.Property | null = null
  private commandProperty: ssap.Property | null = null
  private responseProperty: ssap.Property | null = null
  private address: string = ''
  private discoveredAddress: string = ''
  private connected: boolean = false
  private scanListenerRegistered: boolean = false
  private pending: PendingResponse | null = null
  private sourceId: number = 0x4D4F4249
  private bootId: number = (Date.now() >>> 0) || 1
  private messageId: number = 1
  private primaryCard: PhysicalCard | null = null
  private lastPackage: CardWritePackage | null = null
  private lastGeneration: string = ''
  private discoveryListener: PhysicalCardDiscoveryListener | null = null

  private readonly propertyChanged = (property: ssap.Property): void => {
    if (!this.matchesUuid(property.propertyUuid, CARD_C_RESPONSE_UUID)) return
    try {
      this.acceptResponse(CardCProtocol.decode(property.value))
    } catch (error) {
      this.failPending(error instanceof Error ? error : new Error(`${error}`))
    }
  }

  private readonly connectionChanged = (change: ssap.ConnectionChangeState): void => {
    if (change.state === constant.ConnectionState.STATE_DISCONNECTED) {
      this.connected = false
      this.failPending(new Error('Card C disconnected'))
      if (this.primaryCard) {
        this.primaryCard.connectionState = PhysicalCardConnectionState.DISCONNECTED
      }
    }
  }

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async scanAndSelect(target: CardWriteTarget): Promise<string> {
    if (this.connected && this.address.length > 0 &&
      (!this.primaryCard || target.cardAnonId.length === 0 ||
        this.primaryCard.cardAnonId === target.cardAnonId)) {
      return this.address
    }
    if (!await this.ensurePermission() || manager.getState() !== manager.NearlinkState.STATE_ON) {
      throw new Error('NearLink is unavailable')
    }
    if (this.discoveredAddress.length > 0) return this.discoveredAddress
    return await new Promise<string>((resolve, reject) => {
      let completed: boolean = false
      const finish = (address: string, error: Error | null): void => {
        if (completed) return
        completed = true
        this.stopRawScan().then(() => {
          if (error) reject(error)
          else resolve(address)
        })
      }
      const found = (results: Array<scan.ScanResults>): void => {
        results.forEach((result: scan.ScanResults) => {
          const name: string = result.deviceName.split('\u0000').join('').trim()
          if (result.isConnectable && name === CARD_C_DEVICE_NAME) {
            this.discoveredAddress = result.address
            finish(result.address, null)
          }
        })
      }
      scan.on('deviceFound', found)
      this.scanListenerRegistered = true
      setTimeout(() => finish('', new Error('Card C scan timeout')), SCAN_TIMEOUT_MS)
      scan.startScan([{ deviceName: CARD_C_DEVICE_NAME }], {
        scanMode: scan.ScanMode.SCAN_MODE_BALANCED,
        duration: Math.floor(SCAN_TIMEOUT_MS / 1000)
      }).catch((error: Error) => finish('', error))
    })
  }

  async connect(deviceHandle: string): Promise<void> {
    if (this.connected && this.address === deviceHandle) return
    await this.disconnect()
    this.client = ssap.createClient(deviceHandle)
    this.client.on('connectionStateChange', this.connectionChanged)
    this.client.on('propertyChange', this.propertyChanged)
    await this.client.connect()
    const services: Array<ssap.Service> = await this.client.getServices()
    let service: ssap.Service | null = null
    services.forEach((candidate: ssap.Service) => {
      if (this.matchesUuid(candidate.serviceUuid, CARD_C_SERVICE_UUID)) service = candidate
    })
    if (!service) throw new Error('Card C service UUID was not discovered')
    service.properties.forEach((property: ssap.Property) => {
      if (this.matchesUuid(property.propertyUuid, CARD_C_INFO_UUID)) this.infoProperty = property
      if (this.matchesUuid(property.propertyUuid, CARD_C_COMMAND_UUID)) this.commandProperty = property
      if (this.matchesUuid(property.propertyUuid, CARD_C_RESPONSE_UUID)) this.responseProperty = property
    })
    if (!this.infoProperty || !this.commandProperty || !this.responseProperty) {
      throw new Error('Card C is missing INFO, COMMAND, or RESPONSE')
    }
    await this.client.setPropertyNotification(this.responseProperty, true)
    this.address = deviceHandle
    this.connected = true
  }

  async readCardInfo(): Promise<CardCInfo> {
    if (!this.client || !this.infoProperty) throw new Error('Card C is not connected')
    const value: ssap.Property = await this.client.readProperty(this.infoProperty)
    const frame: CardCFrame = CardCProtocol.decode(value.value)
    if (frame.type !== CardCMessageType.CARD_INFO || frame.payload.byteLength !== 16 ||
      frame.sourceRole !== 1) throw new Error('Card C INFO response is invalid')
    const cardId: number = CardCProtocol.readU32(frame.payload, 4)
    const physicalCardId: string = this.formatCardId(cardId)
    const result: CardCInfo = {
      physicalCardId: physicalCardId,
      cardAnonId: physicalCardId,
      protocolVersion: String(frame.payload[0]),
      maxCredentialChunkBytes: CARD_C_MAX_CHUNK_BYTES
    }
    this.primaryCard = this.toPhysicalCard(result, frame.payload)
    return result
  }

  async authenticate(authorization: CardWriteAuthorization): Promise<void> {
    if (!this.connected || authorization.requestId.length === 0 ||
      authorization.nonce.length === 0 || authorization.writeTicket.length === 0 ||
      Date.parse(authorization.expiresAt) <= Date.now()) {
      throw new Error('Card C write authorization is invalid')
    }
  }

  async beginCredential(writePackage: CardWritePackage): Promise<string> {
    const requestId: number = this.parseRequestId(writePackage.requestId)
    const payload: Uint8Array = new Uint8Array(10)
    CardCProtocol.writeU32(payload, 0, requestId)
    CardCProtocol.writeU16(payload, 4, writePackage.credentialPayload.byteLength)
    CardCProtocol.writeU32(payload, 6, CardCProtocol.crc32(writePackage.credentialPayload))
    await this.sendAndAwait(CardCMessageType.CREDENTIAL_BEGIN, requestId, payload)
    this.lastPackage = writePackage
    return writePackage.requestId
  }

  async writeCredentialChunk(transactionHandle: string, offset: number,
    chunk: Uint8Array): Promise<void> {
    if (chunk.byteLength === 0 || chunk.byteLength > CARD_C_MAX_CHUNK_BYTES) {
      throw new Error('Card C chunk length is invalid')
    }
    const requestId: number = this.parseRequestId(transactionHandle)
    const payload: Uint8Array = new Uint8Array(7 + chunk.byteLength)
    CardCProtocol.writeU32(payload, 0, requestId)
    CardCProtocol.writeU16(payload, 4, offset)
    payload[6] = chunk.byteLength
    payload.set(chunk, 7)
    await this.sendAndAwait(CardCMessageType.CREDENTIAL_CHUNK, requestId, payload)
  }

  async commitCredential(transactionHandle: string): Promise<CardCommitAcknowledgement> {
    const requestId: number = this.parseRequestId(transactionHandle)
    const payload: Uint8Array = new Uint8Array(4)
    CardCProtocol.writeU32(payload, 0, requestId)
    const frames: CardCFrame[] = await this.sendAndAwait(
      CardCMessageType.CREDENTIAL_COMMIT, requestId, payload)
    const result: CardCFrame = frames[frames.length - 1]
    const generation: number = CardCProtocol.readU32(result.payload, 14)
    this.lastGeneration = String(generation)
    return { accepted: generation > 0, generation: this.lastGeneration }
  }

  async listCredentials(): Promise<CardCredentialReadback[]> {
    const requestId: number = this.nextRequestId()
    const payload: Uint8Array = new Uint8Array(4)
    CardCProtocol.writeU32(payload, 0, requestId)
    const frames: CardCFrame[] = await this.sendAndAwait(
      CardCMessageType.CREDENTIAL_LIST, requestId, payload)
    const result: CardCredentialReadback[] = []
    frames.forEach((frame: CardCFrame) => {
      if (frame.type !== CardCMessageType.CREDENTIAL_LIST || frame.payload.byteLength !== 48) return
      const permissionId: string = String(CardCProtocol.readU32(frame.payload, 6))
      const version: number = CardCProtocol.readU32(frame.payload, 39)
      result.push({
        permissionId: permissionId,
        credentialVersion: version,
        generation: this.lastGeneration,
        credentialHash: this.lastPackage && this.lastPackage.permissionId === permissionId &&
          this.lastPackage.credentialVersion === version ? this.lastPackage.credentialHash : ''
      })
    })
    return result
  }

  async disconnect(): Promise<void> {
    this.failPending(new Error('Card C operation was interrupted'))
    if (this.client) {
      try { if (this.responseProperty) await this.client.setPropertyNotification(this.responseProperty, false) } catch (_) {}
      try { await this.client.disconnect() } catch (_) {}
      try { this.client.off('propertyChange', this.propertyChanged) } catch (_) {}
      try { this.client.off('connectionStateChange', this.connectionChanged) } catch (_) {}
      try { this.client.close() } catch (_) {}
    }
    this.client = null
    this.infoProperty = null
    this.commandProperty = null
    this.responseProperty = null
    this.connected = false
    this.address = ''
  }

  async listPhysicalCards(): Promise<PhysicalCard[]> {
    return this.primaryCard ? [this.primaryCard] : []
  }

  async getPrimaryPhysicalCard(): Promise<PhysicalCard | null> { return this.primaryCard }

  async bindPrimaryPhysicalCard(physicalCardId: string): Promise<PrimaryPhysicalCardBindingResult> {
    if (!this.primaryCard || this.primaryCard.physicalCardId !== physicalCardId) {
      return { success: false, reason: PhysicalCardFailureReason.NOT_FOUND, card: null }
    }
    return { success: true, reason: PhysicalCardFailureReason.NONE, card: this.primaryCard }
  }

  async getPhysicalCard(physicalCardId: string): Promise<PhysicalCard | null> {
    return this.primaryCard && this.primaryCard.physicalCardId === physicalCardId ? this.primaryCard : null
  }

  startDiscovery(listener: PhysicalCardDiscoveryListener): void {
    this.discoveryListener = listener
    listener({ state: PhysicalCardDiscoveryState.DISCOVERING, cards: [] })
    this.scanAndSelect({ physicalCardId: '', cardAnonId: '' }).then(async (handle: string) => {
      await this.connect(handle)
      await this.readCardInfo()
      if (this.discoveryListener && this.primaryCard) {
        this.discoveryListener({ state: PhysicalCardDiscoveryState.DISCOVERED, cards: [this.primaryCard] })
      }
    }).catch(() => {
      if (this.discoveryListener) {
        this.discoveryListener({ state: PhysicalCardDiscoveryState.DISCOVERY_FAILED, cards: [] })
      }
    })
  }

  stopDiscovery(): void { this.discoveryListener = null }

  async connectPhysicalCard(physicalCardId: string): Promise<PhysicalCardConnectionResult> {
    try {
      if (!this.connected) {
        const handle: string = await this.scanAndSelect({ physicalCardId, cardAnonId: physicalCardId })
        await this.connect(handle)
        await this.readCardInfo()
      }
      if (!this.primaryCard || this.primaryCard.physicalCardId !== physicalCardId) {
        throw new Error('Card C identity mismatch')
      }
      this.primaryCard.connectionState = PhysicalCardConnectionState.CONNECTED
      return { state: PhysicalCardConnectionState.CONNECTED, reason: PhysicalCardFailureReason.NONE,
        card: this.primaryCard }
    } catch (_) {
      return { state: PhysicalCardConnectionState.CONNECTION_FAILED,
        reason: PhysicalCardFailureReason.CONNECTION_FAILED, card: this.primaryCard }
    }
  }

  async disconnectPhysicalCard(_physicalCardId: string): Promise<PhysicalCardConnectionResult> {
    await this.disconnect()
    if (this.primaryCard) this.primaryCard.connectionState = PhysicalCardConnectionState.DISCONNECTED
    return { state: PhysicalCardConnectionState.DISCONNECTED, reason: PhysicalCardFailureReason.NONE,
      card: this.primaryCard }
  }

  async writeCredential(_request: CredentialWriteRequest,
    listener: CredentialWriteProgressListener): Promise<CredentialWriteResult> {
    listener(CredentialBindingStatus.WRITE_FAILED)
    return this.failedWriteResult()
  }

  cancelCredentialWrite(): void { this.failPending(new Error('Card C write cancelled')) }

  async removeCredential(credentialId: string): Promise<CredentialRemovalResult> {
    return { success: false, reason: PhysicalCardFailureReason.REMOVE_FAILED,
      operation: { operationId: `credential-remove-${credentialId}`, state: OperationState.FAILED,
        authority: OperationAuthority.PHYSICAL_CARD, verificationRequired: true,
        receiptId: '', errorCode: 'notImplemented', updatedAt: new Date().toISOString() },
      credentialId, physicalCard: this.primaryCard, digitalCard: null }
  }

  async listCredentials(_physicalCardId: string): Promise<Credential[]> { return [] }
  async getCredential(_credentialId: string): Promise<Credential | null> { return null }
  translateCredential(_authorization: Authorization, _physicalCardId: string): Credential | null { return null }
  verifyCredential(_credential: Credential, _authorization: Authorization,
    _physicalCardId: string): boolean { return false }

  private async sendAndAwait(commandType: number, requestId: number,
    payload: Uint8Array): Promise<CardCFrame[]> {
    if (!this.client || !this.commandProperty || this.pending) {
      throw new Error('Card C command channel is unavailable or busy')
    }
    const responsePromise: Promise<CardCFrame[]> = new Promise<CardCFrame[]>((resolve, reject) => {
      const timer: number = setTimeout(() => {
        this.failPending(new Error('Card C response timeout'))
      }, RESPONSE_TIMEOUT_MS)
      this.pending = { requestId, commandType, listItems: [], resolve, reject, timer }
    })
    const command: ssap.Property = {
      serviceUuid: this.commandProperty.serviceUuid,
      propertyUuid: this.commandProperty.propertyUuid,
      value: CardCProtocol.encode(commandType, this.sourceId, this.bootId,
        this.messageId++, payload)
    }
    try {
      await this.client.writeProperty(command, ssap.PropertyWriteType.WRITE)
    } catch (error) {
      this.failPending(error instanceof Error ? error : new Error(`${error}`))
    }
    return await responsePromise
  }

  private acceptResponse(frame: CardCFrame): void {
    if (!this.pending || frame.sourceRole !== 1) return
    if (frame.type === CardCMessageType.CREDENTIAL_LIST) {
      if (frame.payload.byteLength === 48 &&
        CardCProtocol.readU32(frame.payload, 0) === this.pending.requestId) {
        this.pending.listItems.push(frame)
      }
      return
    }
    if (frame.type !== CardCMessageType.CREDENTIAL_RESULT || frame.payload.byteLength !== 18 ||
      CardCProtocol.readU32(frame.payload, 0) !== this.pending.requestId ||
      frame.payload[4] !== this.pending.commandType) return
    if (frame.payload[5] !== 0) {
      this.failPending(new Error(`Card C rejected command status=${frame.payload[5]}`))
      return
    }
    const pending: PendingResponse = this.pending
    clearTimeout(pending.timer)
    this.pending = null
    pending.resolve(pending.listItems.concat([frame]))
  }

  private failPending(error: Error): void {
    if (!this.pending) return
    const pending: PendingResponse = this.pending
    clearTimeout(pending.timer)
    this.pending = null
    pending.reject(error)
  }

  private async ensurePermission(): Promise<boolean> {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
    const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(
      this.context, [ACCESS_NEARLINK_PERMISSION])
    return result.authResults.length > 0 &&
      result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
  }

  private async stopRawScan(): Promise<void> {
    try { await scan.stopScan() } catch (_) {}
    if (this.scanListenerRegistered) {
      try { scan.off('deviceFound') } catch (_) {}
      this.scanListenerRegistered = false
    }
  }

  private matchesUuid(value: string, shortUuid: string): boolean {
    const normalized: string = value.split('-').join('').toUpperCase()
    return normalized === shortUuid || normalized.endsWith(shortUuid)
  }

  private parseRequestId(value: string): number {
    const parsed: number = Number(value)
    if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 0xFFFFFFFF) {
      throw new Error('Card C requestId is invalid')
    }
    return parsed >>> 0
  }

  private nextRequestId(): number {
    this.messageId = (this.messageId + 1) >>> 0
    return this.messageId === 0 ? 1 : this.messageId
  }

  private formatCardId(value: number): string {
    return `CARD-${(value >>> 0).toString(16).toUpperCase().padStart(8, '0')}`
  }

  private toPhysicalCard(info: CardCInfo, raw: Uint8Array): PhysicalCard {
    return {
      physicalCardId: info.physicalCardId,
      cardAnonId: info.cardAnonId,
      displayName: 'WS63 Card C',
      hardwareVersion: 'WS63',
      firmwareVersion: String(CardCProtocol.readU32(raw, 8)),
      totalCapacity: raw[1],
      usedCapacity: raw[2],
      credentialIds: [],
      connectionState: PhysicalCardConnectionState.CONNECTED,
      cardStatus: raw[2] >= raw[1] ? PhysicalCardStatus.CAPACITY_FULL : PhysicalCardStatus.AVAILABLE,
      lastSeenAt: new Date().toISOString(),
      lastWrittenAt: '',
      mockFailureMode: MockPhysicalCardFailureMode.NONE
    }
  }

  private failedWriteResult(): CredentialWriteResult {
    return {
      status: CredentialBindingStatus.WRITE_FAILED,
      reason: PhysicalCardFailureReason.WRITE_FAILED,
      operation: { operationId: 'card-write-unavailable', state: OperationState.FAILED,
        authority: OperationAuthority.PHYSICAL_CARD, verificationRequired: true,
        receiptId: '', errorCode: 'useProvisioningCoordinator', updatedAt: new Date().toISOString() },
      credential: null,
      physicalCard: this.primaryCard,
      digitalCard: null
    }
  }
}
