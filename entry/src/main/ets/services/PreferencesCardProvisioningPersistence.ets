import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { PendingWriteReceipt } from '../models/CardProvisioning'
import { CardProvisioningPersistenceService } from './CardProvisioningPersistenceService'

export class PreferencesCardProvisioningPersistence implements
  CardProvisioningPersistenceService {
  private readonly context: common.UIAbilityContext
  private readonly preferenceName: string = 'sle_id_mobile_provisioning'
  private readonly stateKey: string = 'pending_write_receipts_v1'

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async loadPendingReceipts(): Promise<PendingWriteReceipt[]> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        this.context,
        { name: this.preferenceName }
      )
      const serialized: string = await store.get(this.stateKey, '[]') as string
      const parsed: PendingWriteReceipt[] =
        JSON.parse(serialized) as PendingWriteReceipt[]
      if (!Array.isArray(parsed)) {
        return []
      }
      const sanitized: PendingWriteReceipt[] = []
      parsed.forEach((receipt: PendingWriteReceipt) => {
        const item: PendingWriteReceipt = {
          operationId: receipt.operationId || '',
          requestId: receipt.requestId || '',
          digitalCardId: receipt.digitalCardId || '',
          physicalCardId: receipt.physicalCardId || '',
          permissionId: receipt.permissionId || '',
          credentialVersion: receipt.credentialVersion || 0,
          generation: receipt.generation || '',
          credentialHash: receipt.credentialHash || '',
          verifiedAt: receipt.verifiedAt || '',
          createdAt: receipt.createdAt || '',
          lastAttemptAt: receipt.lastAttemptAt || '',
          attemptCount: receipt.attemptCount || 0
        }
        if (item.operationId.length > 0 && item.requestId.length > 0 &&
          item.physicalCardId.length > 0 && item.permissionId.length > 0) {
          sanitized.push(item)
        }
      })
      return sanitized
    } catch (error) {
      return []
    }
  }

  async savePendingReceipts(receipts: PendingWriteReceipt[]): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        this.context,
        { name: this.preferenceName }
      )
      await store.put(this.stateKey, JSON.stringify(receipts))
      await store.flush()
    } catch (error) {
      throw new Error('Unable to persist pending Card C receipts')
    }
  }
}
