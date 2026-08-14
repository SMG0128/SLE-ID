import { describe, expect, it } from '@ohos/hypium'
import {
  CARD_CREDENTIAL_PAYLOAD_LENGTH,
  CardCInfo,
  CardCommitAcknowledgement,
  CardCredentialReadback,
  CardProvisioningFailure,
  CardProvisioningResult,
  CardProvisioningStage,
  CardWriteAuthorization,
  CardWritePackage,
  CardWriteTarget,
  PendingWriteReceipt,
  WriteReceiptAcknowledgement
} from '../main/ets/models/CardProvisioning'
import { CredentialBindingStatus } from '../main/ets/models/Credential'
import { OperationState } from '../main/ets/models/Operation'
import {
  CardProvisioningCoordinator,
  CardWritePackageSource,
  CardWriteReceiptSink
} from '../main/ets/services/CardProvisioningService'
import { CardSleClient } from '../main/ets/services/CardSleClient'
import { InMemoryCardProvisioningPersistence } from '../main/ets/services/InMemoryCardProvisioningPersistence'
import {
  NearLinkFrame,
  NearLinkMessageType,
  NearLinkProtocol
} from '../main/ets/services/NearLinkProtocol'

const NOW: string = '2026-08-14T08:00:00.000Z'

function writePackage(
  requestId: string = 'write-request-1',
  expiresAt: string = '2026-08-14T08:05:00.000Z'
): CardWritePackage {
  const payload: Uint8Array = new Uint8Array(CARD_CREDENTIAL_PAYLOAD_LENGTH)
  for (let index: number = 0; index < payload.byteLength; index++) {
    payload[index] = index & 0xFF
  }
  return {
    requestId: requestId,
    digitalCardId: 'card-1',
    target: {
      physicalCardId: 'card-c-1',
      cardAnonId: 'anon-card-c-1'
    },
    permissionId: 'permission-1',
    credentialVersion: 7,
    credentialPayload: payload,
    credentialHash: 'hash-credential-1',
    expireAt: expiresAt,
    authorization: {
      requestId: requestId,
      nonce: 'opaque-nonce',
      expiresAt: expiresAt,
      writeTicket: 'opaque-ticket'
    }
  }
}

class StaticPackageSource implements CardWritePackageSource {
  readonly value: CardWritePackage
  calls: number = 0

  constructor(value: CardWritePackage) {
    this.value = value
  }

  async obtainWritePackage(
    digitalCardId: string,
    physicalCardId: string
  ): Promise<CardWritePackage> {
    this.calls++
    return this.value
  }
}

class ControlledReceiptSink implements CardWriteReceiptSink {
  fail: boolean = false
  calls: number = 0

  async uploadWriteReceipt(
    receipt: PendingWriteReceipt
  ): Promise<WriteReceiptAcknowledgement> {
    this.calls++
    if (this.fail) {
      throw new Error('backend unavailable')
    }
    return {
      receiptId: `backend-${receipt.requestId}`,
      acknowledgedAt: NOW
    }
  }
}

class RecordingCardSleClient implements CardSleClient {
  failChunk: boolean = false
  mismatchReadback: boolean = false
  authenticateCalls: number = 0
  beginCalls: number = 0
  chunkCalls: number = 0
  commitCalls: number = 0
  readbackCalls: number = 0
  disconnectCalls: number = 0

  async scanAndSelect(target: CardWriteTarget): Promise<string> {
    return `device-${target.physicalCardId}`
  }

  async connect(deviceHandle: string): Promise<void> {}

  async readCardInfo(): Promise<CardCInfo> {
    return {
      physicalCardId: 'card-c-1',
      cardAnonId: 'anon-card-c-1',
      protocolVersion: 'external-contract',
      maxCredentialChunkBytes: 20
    }
  }

  async authenticate(authorization: CardWriteAuthorization): Promise<void> {
    this.authenticateCalls++
  }

  async beginCredential(value: CardWritePackage): Promise<string> {
    this.beginCalls++
    return `transaction-${value.requestId}`
  }

  async writeCredentialChunk(
    transactionHandle: string,
    offset: number,
    chunk: Uint8Array
  ): Promise<void> {
    this.chunkCalls++
    if (this.failChunk) {
      throw new Error('chunk rejected')
    }
  }

  async commitCredential(
    transactionHandle: string
  ): Promise<CardCommitAcknowledgement> {
    this.commitCalls++
    return {
      accepted: true,
      generation: 'generation-9'
    }
  }

  async listCredentials(): Promise<CardCredentialReadback[]> {
    this.readbackCalls++
    return [{
      permissionId: 'permission-1',
      credentialVersion: this.mismatchReadback ? 8 : 7,
      generation: 'generation-9',
      credentialHash: 'hash-credential-1'
    }]
  }

  async disconnect(): Promise<void> {
    this.disconnectCalls++
  }
}

async function coordinator(
  source: StaticPackageSource,
  client: RecordingCardSleClient,
  sink: ControlledReceiptSink,
  persistence: InMemoryCardProvisioningPersistence
): Promise<CardProvisioningCoordinator> {
  const service: CardProvisioningCoordinator = new CardProvisioningCoordinator(
    source,
    client,
    sink,
    persistence
  )
  await service.initialize()
  return service
}

export default function cardProvisioningTest() {
  describe('Card C mobile provisioning contracts', () => {
    it('does not become active before verified readback and receipt acknowledgement', 0, async () => {
      const source: StaticPackageSource = new StaticPackageSource(writePackage())
      const client: RecordingCardSleClient = new RecordingCardSleClient()
      const sink: ControlledReceiptSink = new ControlledReceiptSink()
      const service: CardProvisioningCoordinator = await coordinator(
        source,
        client,
        sink,
        new InMemoryCardProvisioningPersistence()
      )
      const stages: CardProvisioningStage[] = []
      const result: CardProvisioningResult = await service.provision(
        'card-1',
        'card-c-1',
        (stage: CardProvisioningStage) => stages.push(stage),
        NOW
      )
      expect(result.credentialStatus).assertEqual(CredentialBindingStatus.ACTIVE)
      expect(result.physicalOperation.state).assertEqual(OperationState.VERIFIED)
      expect(result.backendAcknowledged).assertTrue()
      expect(stages.indexOf(CardProvisioningStage.VERIFYING)).assertLarger(-1)
      expect(stages.indexOf(CardProvisioningStage.SYNCHRONIZING)).assertLarger(
        stages.indexOf(CardProvisioningStage.VERIFYING)
      )
      expect(stages.indexOf(CardProvisioningStage.SUCCESS)).assertLarger(
        stages.indexOf(CardProvisioningStage.SYNCHRONIZING)
      )
    })

    it('keeps a chunk failure non-active and retryable', 0, async () => {
      const source: StaticPackageSource = new StaticPackageSource(writePackage())
      const client: RecordingCardSleClient = new RecordingCardSleClient()
      client.failChunk = true
      const service: CardProvisioningCoordinator = await coordinator(
        source,
        client,
        new ControlledReceiptSink(),
        new InMemoryCardProvisioningPersistence()
      )
      const result: CardProvisioningResult = await service.provision(
        'card-1', 'card-c-1', (_stage: CardProvisioningStage) => {}, NOW
      )
      expect(result.stage).assertEqual(CardProvisioningStage.RETRYABLE_FAILURE)
      expect(result.failure).assertEqual(CardProvisioningFailure.CHUNK_WRITE_FAILED)
      expect(result.credentialStatus).assertEqual(
        CredentialBindingStatus.WRITE_FAILED
      )
      expect(result.physicalVerified).assertFalse()
    })

    it('rejects a readback mismatch after commit', 0, async () => {
      const client: RecordingCardSleClient = new RecordingCardSleClient()
      client.mismatchReadback = true
      const service: CardProvisioningCoordinator = await coordinator(
        new StaticPackageSource(writePackage()),
        client,
        new ControlledReceiptSink(),
        new InMemoryCardProvisioningPersistence()
      )
      const result: CardProvisioningResult = await service.provision(
        'card-1', 'card-c-1', (_stage: CardProvisioningStage) => {}, NOW
      )
      expect(result.failure).assertEqual(CardProvisioningFailure.READBACK_MISMATCH)
      expect(result.credentialStatus).assertEqual(
        CredentialBindingStatus.WRITE_FAILED
      )
      expect(result.physicalVerified).assertFalse()
    })

    it('rejects expired and replayed write authorization at the mobile layer', 0, async () => {
      const expiredClient: RecordingCardSleClient = new RecordingCardSleClient()
      const expiredService: CardProvisioningCoordinator = await coordinator(
        new StaticPackageSource(writePackage(
          'expired-request',
          '2026-08-14T07:59:59.000Z'
        )),
        expiredClient,
        new ControlledReceiptSink(),
        new InMemoryCardProvisioningPersistence()
      )
      const expired: CardProvisioningResult = await expiredService.provision(
        'card-1', 'card-c-1', (_stage: CardProvisioningStage) => {}, NOW
      )
      expect(expired.failure).assertEqual(
        CardProvisioningFailure.AUTHORIZATION_EXPIRED
      )
      expect(expiredClient.authenticateCalls).assertEqual(0)

      const replayClient: RecordingCardSleClient = new RecordingCardSleClient()
      const replayService: CardProvisioningCoordinator = await coordinator(
        new StaticPackageSource(writePackage('replay-request')),
        replayClient,
        new ControlledReceiptSink(),
        new InMemoryCardProvisioningPersistence()
      )
      await replayService.provision(
        'card-1', 'card-c-1', (_stage: CardProvisioningStage) => {}, NOW
      )
      const replay: CardProvisioningResult = await replayService.provision(
        'card-1', 'card-c-1', (_stage: CardProvisioningStage) => {}, NOW
      )
      expect(replay.failure).assertEqual(
        CardProvisioningFailure.AUTHORIZATION_REPLAYED
      )
      expect(replayClient.authenticateCalls).assertEqual(1)
    })

    it('persists a pending receipt when backend upload fails', 0, async () => {
      const persistence: InMemoryCardProvisioningPersistence =
        new InMemoryCardProvisioningPersistence()
      const sink: ControlledReceiptSink = new ControlledReceiptSink()
      sink.fail = true
      const service: CardProvisioningCoordinator = await coordinator(
        new StaticPackageSource(writePackage()),
        new RecordingCardSleClient(),
        sink,
        persistence
      )
      const result: CardProvisioningResult = await service.provision(
        'card-1', 'card-c-1', (_stage: CardProvisioningStage) => {}, NOW
      )
      expect(result.physicalVerified).assertTrue()
      expect(result.backendAcknowledged).assertFalse()
      expect(result.receiptPending).assertTrue()
      expect(result.stage).assertEqual(CardProvisioningStage.SYNCHRONIZING)
      expect(service.pendingReceiptCount()).assertEqual(1)
      expect((await persistence.loadPendingReceipts()).length).assertEqual(1)
    })

    it('retries only the pending receipt without repeating physical provisioning', 0, async () => {
      const client: RecordingCardSleClient = new RecordingCardSleClient()
      const sink: ControlledReceiptSink = new ControlledReceiptSink()
      sink.fail = true
      const service: CardProvisioningCoordinator = await coordinator(
        new StaticPackageSource(writePackage()),
        client,
        sink,
        new InMemoryCardProvisioningPersistence()
      )
      await service.provision(
        'card-1', 'card-c-1', (_stage: CardProvisioningStage) => {}, NOW
      )
      const beginCalls: number = client.beginCalls
      const commitCalls: number = client.commitCalls
      sink.fail = false
      const recovered: number = await service.retryPendingReceipts(
        '2026-08-14T08:01:00.000Z'
      )
      expect(recovered).assertEqual(1)
      expect(service.pendingReceiptCount()).assertEqual(0)
      expect(client.beginCalls).assertEqual(beginCalls)
      expect(client.commitCalls).assertEqual(commitCalls)
    })

    it('recovers a pending receipt after restart without a second Card C write', 0, async () => {
      const persistence: InMemoryCardProvisioningPersistence =
        new InMemoryCardProvisioningPersistence()
      const firstSink: ControlledReceiptSink = new ControlledReceiptSink()
      firstSink.fail = true
      const firstClient: RecordingCardSleClient = new RecordingCardSleClient()
      const first: CardProvisioningCoordinator = await coordinator(
        new StaticPackageSource(writePackage('restart-request')),
        firstClient,
        firstSink,
        persistence
      )
      await first.provision(
        'card-1', 'card-c-1', (_stage: CardProvisioningStage) => {}, NOW
      )

      const recoveryClient: RecordingCardSleClient = new RecordingCardSleClient()
      const recovered: CardProvisioningCoordinator = await coordinator(
        new StaticPackageSource(writePackage('restart-request')),
        recoveryClient,
        new ControlledReceiptSink(),
        persistence
      )
      expect(recovered.pendingReceiptCount()).assertEqual(1)
      expect(await recovered.retryPendingReceipts(
        '2026-08-14T08:02:00.000Z'
      )).assertEqual(1)
      expect(recoveryClient.beginCalls).assertEqual(0)
      expect(recoveryClient.chunkCalls).assertEqual(0)
      expect(recoveryClient.commitCalls).assertEqual(0)
      expect(recovered.pendingReceiptCount()).assertEqual(0)
    })

    it('round-trips the existing diagnostic binary frame contract', 0, () => {
      const payload: Uint8Array = new Uint8Array([0x10, 0x20, 0x30])
      const encoded: ArrayBuffer = NearLinkProtocol.encode(
        NearLinkMessageType.HELLO,
        0x1234,
        payload
      )
      expect(NearLinkProtocol.hex(new Uint8Array(encoded))).assertEqual(
        '53 4B 01 01 34 12 03 00 10 20 30 F8 0C'
      )
      const frame: NearLinkFrame = NearLinkProtocol.decode(encoded)
      expect(frame.type).assertEqual(NearLinkMessageType.HELLO)
      expect(frame.sequence).assertEqual(0x1234)
      expect(frame.payload.byteLength).assertEqual(3)
      expect(frame.payload[2]).assertEqual(0x30)
    })

    it('rejects a malformed diagnostic frame without defining Card C commands', 0, () => {
      const encoded: ArrayBuffer = NearLinkProtocol.encode(
        NearLinkMessageType.PING,
        9
      )
      const bytes: Uint8Array = new Uint8Array(encoded)
      bytes[bytes.byteLength - 1] ^= 0xFF
      let rejected: boolean = false
      try {
        NearLinkProtocol.decode(bytes.buffer)
      } catch (error) {
        rejected = true
      }
      expect(rejected).assertTrue()
    })
  })
}
