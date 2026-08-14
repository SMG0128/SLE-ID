import { PendingWriteReceipt } from '../models/CardProvisioning'
import { CardProvisioningPersistenceService } from './CardProvisioningPersistenceService'

export class InMemoryCardProvisioningPersistence implements
  CardProvisioningPersistenceService {
  private receipts: PendingWriteReceipt[] = []

  async loadPendingReceipts(): Promise<PendingWriteReceipt[]> {
    const result: PendingWriteReceipt[] = []
    this.receipts.forEach((receipt: PendingWriteReceipt) => {
      result.push(this.cloneReceipt(receipt))
    })
    return result
  }

  async savePendingReceipts(receipts: PendingWriteReceipt[]): Promise<void> {
    const result: PendingWriteReceipt[] = []
    receipts.forEach((receipt: PendingWriteReceipt) => {
      result.push(this.cloneReceipt(receipt))
    })
    this.receipts = result
  }

  private cloneReceipt(receipt: PendingWriteReceipt): PendingWriteReceipt {
    const clone: PendingWriteReceipt = {
      operationId: receipt.operationId,
      requestId: receipt.requestId,
      digitalCardId: receipt.digitalCardId,
      physicalCardId: receipt.physicalCardId,
      permissionId: receipt.permissionId,
      credentialVersion: receipt.credentialVersion,
      generation: receipt.generation,
      credentialHash: receipt.credentialHash,
      verifiedAt: receipt.verifiedAt,
      createdAt: receipt.createdAt,
      lastAttemptAt: receipt.lastAttemptAt,
      attemptCount: receipt.attemptCount
    }
    return clone
  }
}
