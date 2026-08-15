import {
  CARD_CREDENTIAL_PAYLOAD_LENGTH,
  CardCInfo,
  CardCommitAcknowledgement,
  CardCredentialReadback,
  CardProvisioningFailure,
  CardProvisioningResult,
  CardProvisioningStage,
  CardProvisioningStageListener,
  CardWritePackage,
  PendingWriteReceipt,
  WriteReceiptAcknowledgement,
  createIdleProvisioningResult,
  emptyProvisioningOperation
} from '../models/CardProvisioning'
import { CredentialBindingStatus } from '../models/Credential'
import {
  OperationAuthority,
  OperationReceipt,
  OperationState
} from '../models/Operation'
import { CardProvisioningPersistenceService } from './CardProvisioningPersistenceService'
import { CardSleClient } from './CardSleClient'

export interface CardWritePackageSource {
  obtainWritePackage(
    digitalCardId: string,
    physicalCardId: string
  ): Promise<CardWritePackage>
}

export interface CardWriteReceiptSink {
  uploadWriteReceipt(
    receipt: PendingWriteReceipt
  ): Promise<WriteReceiptAcknowledgement>
}

export interface CardProvisioningCoordinatorService {
  initialize(): Promise<void>
  provision(
    digitalCardId: string,
    physicalCardId: string,
    listener: CardProvisioningStageListener,
    now?: string
  ): Promise<CardProvisioningResult>
  retryPendingReceipts(now?: string): Promise<number>
  pendingReceiptCount(): number
}

export class CardProvisioningCoordinator implements
  CardProvisioningCoordinatorService {
  private readonly packageSource: CardWritePackageSource
  private readonly cardClient: CardSleClient
  private readonly receiptSink: CardWriteReceiptSink
  private readonly persistence: CardProvisioningPersistenceService
  private pendingReceipts: PendingWriteReceipt[] = []
  private consumedRequestIds: Set<string> = new Set<string>()
  private provisioning: boolean = false

  constructor(
    packageSource: CardWritePackageSource,
    cardClient: CardSleClient,
    receiptSink: CardWriteReceiptSink,
    persistence: CardProvisioningPersistenceService
  ) {
    this.packageSource = packageSource
    this.cardClient = cardClient
    this.receiptSink = receiptSink
    this.persistence = persistence
  }

  async initialize(): Promise<void> {
    this.pendingReceipts = await this.persistence.loadPendingReceipts()
    this.pendingReceipts.forEach((receipt: PendingWriteReceipt) => {
      this.consumedRequestIds.add(receipt.requestId)
    })
  }

  pendingReceiptCount(): number {
    return this.pendingReceipts.length
  }

  async provision(
    digitalCardId: string,
    physicalCardId: string,
    listener: CardProvisioningStageListener,
    now: string = new Date().toISOString()
  ): Promise<CardProvisioningResult> {
    if (this.provisioning) {
      return this.failureResult(
        '',
        CardProvisioningFailure.CONNECTION_INTERRUPTED,
        now
      )
    }
    this.provisioning = true
    let writePackage: CardWritePackage | null = null
    try {
      try {
        writePackage = await this.packageSource.obtainWritePackage(
          digitalCardId,
          physicalCardId
        )
      } catch (error) {
        return this.failureResult(
          '',
          CardProvisioningFailure.INVALID_WRITE_PACKAGE,
          now
        )
      }
      if (!this.isWritePackageValid(
        writePackage,
        digitalCardId,
        physicalCardId
      )) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.INVALID_WRITE_PACKAGE,
          now
        )
      }
      if (this.isExpired(writePackage, now)) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.AUTHORIZATION_EXPIRED,
          now
        )
      }
      if (this.consumedRequestIds.has(writePackage.requestId)) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.AUTHORIZATION_REPLAYED,
          now
        )
      }

      listener(CardProvisioningStage.SCANNING)
      let deviceHandle: string = ''
      try {
        deviceHandle = await this.cardClient.scanAndSelect(writePackage.target)
      } catch (error) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.SCAN_TIMEOUT,
          now
        )
      }
      if (deviceHandle.length === 0) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.SCAN_TIMEOUT,
          now
        )
      }

      listener(CardProvisioningStage.CONNECTING)
      try {
        await this.cardClient.connect(deviceHandle)
      } catch (error) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.CONNECTION_FAILED,
          now
        )
      }

      let cardInfo: CardCInfo
      try {
        cardInfo = await this.cardClient.readCardInfo()
      } catch (error) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.IDENTITY_MISMATCH,
          now
        )
      }
      if (!this.matchesTarget(cardInfo, writePackage) ||
        cardInfo.maxCredentialChunkBytes <= 0) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.IDENTITY_MISMATCH,
          now
        )
      }

      listener(CardProvisioningStage.AUTHENTICATING)
      try {
        await this.cardClient.authenticate(writePackage.authorization)
      } catch (error) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.AUTHENTICATION_FAILED,
          now
        )
      }
      // A ticket is single-attempt on mobile once Card C accepts it. A retry
      // obtains a new package instead of replaying authorization material.
      this.consumedRequestIds.add(writePackage.requestId)

      listener(CardProvisioningStage.WRITING)
      let transactionHandle: string = ''
      try {
        transactionHandle = await this.cardClient.beginCredential(writePackage)
        if (transactionHandle.length === 0) {
          throw new Error('Card C omitted transaction handle')
        }
        await this.writeChunks(
          transactionHandle,
          writePackage.credentialPayload,
          cardInfo.maxCredentialChunkBytes
        )
      } catch (error) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.CHUNK_WRITE_FAILED,
          now
        )
      }

      let commit: CardCommitAcknowledgement
      try {
        commit = await this.cardClient.commitCredential(transactionHandle)
      } catch (error) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.COMMIT_FAILED,
          now
        )
      }
      if (!commit.accepted || commit.generation.length === 0) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.COMMIT_FAILED,
          now
        )
      }

      listener(CardProvisioningStage.VERIFYING)
      let readback: CardCredentialReadback | null = null
      try {
        readback = this.findReadback(
          await this.cardClient.listCredentialReadback(),
          writePackage,
          commit.generation
        )
      } catch (error) {
        readback = null
      }
      if (!readback) {
        return this.failureResult(
          writePackage.requestId,
          CardProvisioningFailure.READBACK_MISMATCH,
          now
        )
      }

      const physicalOperation: OperationReceipt = {
        operationId: `card-write-${writePackage.requestId}`,
        state: OperationState.VERIFIED,
        authority: OperationAuthority.PHYSICAL_CARD,
        verificationRequired: true,
        receiptId: `card-readback-${writePackage.requestId}`,
        errorCode: '',
        updatedAt: now
      }
      const pendingReceipt: PendingWriteReceipt = {
        operationId: `write-receipt-${writePackage.requestId}`,
        requestId: writePackage.requestId,
        digitalCardId: writePackage.digitalCardId,
        physicalCardId: writePackage.target.physicalCardId,
        permissionId: writePackage.permissionId,
        credentialVersion: writePackage.credentialVersion,
        generation: readback.generation,
        credentialHash: readback.credentialHash,
        verifiedAt: now,
        createdAt: now,
        lastAttemptAt: '',
        attemptCount: 0
      }
      this.pendingReceipts.push(pendingReceipt)
      try {
        await this.persistence.savePendingReceipts(this.pendingReceipts)
      } catch (error) {
        return this.synchronizationFailureResult(
          writePackage.requestId,
          CardProvisioningFailure.RECEIPT_PERSISTENCE_FAILED,
          physicalOperation,
          false,
          now
        )
      }

      listener(CardProvisioningStage.SYNCHRONIZING)
      let acknowledgement: WriteReceiptAcknowledgement
      try {
        acknowledgement = await this.receiptSink.uploadWriteReceipt(
          pendingReceipt
        )
        if (acknowledgement.receiptId.length === 0) {
          throw new Error('Backend omitted write receipt acknowledgement')
        }
      } catch (error) {
        pendingReceipt.lastAttemptAt = now
        pendingReceipt.attemptCount++
        try {
          await this.persistence.savePendingReceipts(this.pendingReceipts)
        } catch (persistenceError) {
          return this.synchronizationFailureResult(
            writePackage.requestId,
            CardProvisioningFailure.RECEIPT_PERSISTENCE_FAILED,
            physicalOperation,
            true,
            now
          )
        }
        return this.synchronizationFailureResult(
          writePackage.requestId,
          CardProvisioningFailure.RECEIPT_UPLOAD_FAILED,
          physicalOperation,
          true,
          now
        )
      }
      const receiptOperation: OperationReceipt = {
        operationId: pendingReceipt.operationId,
        state: OperationState.ACKNOWLEDGED,
        authority: OperationAuthority.BACKEND,
        verificationRequired: false,
        receiptId: acknowledgement.receiptId,
        errorCode: '',
        updatedAt: acknowledgement.acknowledgedAt || now
      }
      try {
        await this.removePendingReceipt(pendingReceipt.operationId)
      } catch (error) {
        return {
          stage: CardProvisioningStage.SYNCHRONIZING,
          failure: CardProvisioningFailure.RECEIPT_PERSISTENCE_FAILED,
          credentialStatus: CredentialBindingStatus.ACTIVE,
          physicalVerified: true,
          backendAcknowledged: true,
          receiptPending: true,
          requestId: writePackage.requestId,
          physicalOperation: physicalOperation,
          receiptOperation: receiptOperation
        }
      }
      listener(CardProvisioningStage.SUCCESS)
      return {
        stage: CardProvisioningStage.SUCCESS,
        failure: CardProvisioningFailure.NONE,
        credentialStatus: CredentialBindingStatus.ACTIVE,
        physicalVerified: true,
        backendAcknowledged: true,
        receiptPending: false,
        requestId: writePackage.requestId,
        physicalOperation: physicalOperation,
        receiptOperation: receiptOperation
      }
    } finally {
      try {
        await this.cardClient.disconnect()
      } catch (error) {
        // Cleanup failure cannot turn a failed or verified transaction into success.
        console.warn('[SLE-ID][CardProvisioning] Card C disconnect cleanup failed.')
      }
      this.provisioning = false
    }
  }

  async retryPendingReceipts(
    now: string = new Date().toISOString()
  ): Promise<number> {
    let acknowledged: number = 0
    const snapshot: PendingWriteReceipt[] = this.pendingReceipts.slice()
    for (let index: number = 0; index < snapshot.length; index++) {
      const receipt: PendingWriteReceipt = snapshot[index]
      receipt.lastAttemptAt = now
      receipt.attemptCount++
      try {
        const result: WriteReceiptAcknowledgement =
          await this.receiptSink.uploadWriteReceipt(receipt)
        if (result.receiptId.length === 0) {
          continue
        }
        await this.removePendingReceipt(receipt.operationId)
        acknowledged++
      } catch (error) {
        // Retain the safe receipt for controlled network recovery.
      }
    }
    await this.persistence.savePendingReceipts(this.pendingReceipts)
    return acknowledged
  }

  private async writeChunks(
    transactionHandle: string,
    payload: Uint8Array,
    chunkSize: number
  ): Promise<void> {
    let offset: number = 0
    while (offset < payload.byteLength) {
      const end: number = Math.min(offset + chunkSize, payload.byteLength)
      const chunk: Uint8Array = new Uint8Array(end - offset)
      chunk.set(payload.subarray(offset, end))
      await this.cardClient.writeCredentialChunk(
        transactionHandle,
        offset,
        chunk
      )
      offset = end
    }
  }

  private findReadback(
    credentials: CardCredentialReadback[],
    writePackage: CardWritePackage,
    generation: string
  ): CardCredentialReadback | null {
    let result: CardCredentialReadback | null = null
    credentials.forEach((credential: CardCredentialReadback) => {
      if (credential.permissionId === writePackage.permissionId &&
        credential.credentialVersion === writePackage.credentialVersion &&
        credential.generation === generation &&
        credential.credentialHash === writePackage.credentialHash) {
        result = credential
      }
    })
    return result
  }

  private isWritePackageValid(
    writePackage: CardWritePackage,
    digitalCardId: string,
    physicalCardId: string
  ): boolean {
    return writePackage.requestId.length > 0 &&
      writePackage.digitalCardId === digitalCardId &&
      writePackage.target.physicalCardId === physicalCardId &&
      writePackage.target.cardAnonId.length > 0 &&
      writePackage.permissionId.length > 0 &&
      writePackage.credentialVersion > 0 &&
      writePackage.credentialPayload.byteLength ===
        CARD_CREDENTIAL_PAYLOAD_LENGTH &&
      writePackage.credentialHash.length > 0 &&
      writePackage.expireAt.length > 0 &&
      writePackage.authorization.requestId === writePackage.requestId &&
      writePackage.authorization.nonce.length > 0 &&
      writePackage.authorization.expiresAt.length > 0 &&
      writePackage.authorization.writeTicket.length > 0
  }

  private isExpired(writePackage: CardWritePackage, now: string): boolean {
    const nowValue: number = Date.parse(now)
    const packageExpiry: number = Date.parse(writePackage.expireAt)
    const ticketExpiry: number = Date.parse(writePackage.authorization.expiresAt)
    return !Number.isFinite(nowValue) ||
      !Number.isFinite(packageExpiry) ||
      !Number.isFinite(ticketExpiry) ||
      packageExpiry <= nowValue || ticketExpiry <= nowValue
  }

  private matchesTarget(
    info: CardCInfo,
    writePackage: CardWritePackage
  ): boolean {
    return info.physicalCardId === writePackage.target.physicalCardId &&
      info.cardAnonId === writePackage.target.cardAnonId
  }

  private async removePendingReceipt(operationId: string): Promise<void> {
    this.pendingReceipts = this.pendingReceipts.filter(
      (receipt: PendingWriteReceipt) => receipt.operationId !== operationId
    )
    await this.persistence.savePendingReceipts(this.pendingReceipts)
  }

  private failureResult(
    requestId: string,
    failure: CardProvisioningFailure,
    now: string
  ): CardProvisioningResult {
    const result: CardProvisioningResult = createIdleProvisioningResult()
    result.stage = CardProvisioningStage.RETRYABLE_FAILURE
    result.failure = failure
    result.credentialStatus = CredentialBindingStatus.WRITE_FAILED
    result.requestId = requestId
    result.physicalOperation = {
      operationId: requestId.length > 0 ? `card-write-${requestId}` : '',
      state: OperationState.FAILED,
      authority: OperationAuthority.PHYSICAL_CARD,
      verificationRequired: true,
      receiptId: '',
      errorCode: failure,
      updatedAt: now
    }
    result.receiptOperation = emptyProvisioningOperation()
    return result
  }

  private synchronizationFailureResult(
    requestId: string,
    failure: CardProvisioningFailure,
    physicalOperation: OperationReceipt,
    persisted: boolean,
    now: string
  ): CardProvisioningResult {
    return {
      stage: CardProvisioningStage.SYNCHRONIZING,
      failure: failure,
      credentialStatus: CredentialBindingStatus.ACTIVE,
      physicalVerified: true,
      backendAcknowledged: false,
      receiptPending: persisted,
      requestId: requestId,
      physicalOperation: physicalOperation,
      receiptOperation: {
        operationId: `write-receipt-${requestId}`,
        state: OperationState.FAILED,
        authority: OperationAuthority.BACKEND,
        verificationRequired: false,
        receiptId: '',
        errorCode: failure,
        updatedAt: now
      }
    }
  }
}
