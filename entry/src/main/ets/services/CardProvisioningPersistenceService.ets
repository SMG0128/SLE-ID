import { PendingWriteReceipt } from '../models/CardProvisioning'

export interface CardProvisioningPersistenceService {
  loadPendingReceipts(): Promise<PendingWriteReceipt[]>
  savePendingReceipts(receipts: PendingWriteReceipt[]): Promise<void>
}
