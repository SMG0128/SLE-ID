import { Authorization } from '../models/Authorization'
import { Credential, CredentialBindingStatus } from '../models/Credential'
import {
  OperationAuthority,
  OperationReceipt,
  OperationState
} from '../models/Operation'
import {
  PhysicalCard,
  PhysicalCardConnectionState,
  PhysicalCardDiscoveryState
} from '../models/PhysicalCard'
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
import { CredentialService } from './CredentialService'
import { PhysicalCardService } from './PhysicalCardService'

// Production must never fall back to Mock Card C success. Until an adapter is
// supplied from the authoritative firmware contract, this service fails closed.
export class UnavailableCardCService implements
  PhysicalCardService,
  CredentialService {
  async listPhysicalCards(): Promise<PhysicalCard[]> {
    return []
  }

  async getPrimaryPhysicalCard(): Promise<PhysicalCard | null> {
    return null
  }

  async bindPrimaryPhysicalCard(
    physicalCardId: string
  ): Promise<PrimaryPhysicalCardBindingResult> {
    return {
      success: false,
      reason: PhysicalCardFailureReason.DISCOVERY_FAILED,
      card: null
    }
  }

  async getPhysicalCard(physicalCardId: string): Promise<PhysicalCard | null> {
    return null
  }

  startDiscovery(listener: PhysicalCardDiscoveryListener): void {
    listener({
      state: PhysicalCardDiscoveryState.DISCOVERY_FAILED,
      cards: []
    })
  }

  stopDiscovery(): void {}

  async connectPhysicalCard(
    physicalCardId: string
  ): Promise<PhysicalCardConnectionResult> {
    return {
      state: PhysicalCardConnectionState.CONNECTION_FAILED,
      reason: PhysicalCardFailureReason.CONNECTION_FAILED,
      card: null
    }
  }

  async disconnectPhysicalCard(
    physicalCardId: string
  ): Promise<PhysicalCardConnectionResult> {
    return {
      state: PhysicalCardConnectionState.DISCONNECTED,
      reason: PhysicalCardFailureReason.NONE,
      card: null
    }
  }

  async writeCredential(
    request: CredentialWriteRequest,
    listener: CredentialWriteProgressListener
  ): Promise<CredentialWriteResult> {
    listener(CredentialBindingStatus.WRITE_FAILED)
    return {
      status: CredentialBindingStatus.WRITE_FAILED,
      reason: PhysicalCardFailureReason.WRITE_FAILED,
      operation: this.failedOperation(`card-write-${request.permissionId}`),
      credential: null,
      physicalCard: null,
      digitalCard: null
    }
  }

  cancelCredentialWrite(): void {}

  async removeCredential(
    credentialId: string
  ): Promise<CredentialRemovalResult> {
    return {
      success: false,
      reason: PhysicalCardFailureReason.REMOVE_FAILED,
      operation: this.failedOperation(`credential-remove-${credentialId}`),
      credentialId: credentialId,
      physicalCard: null,
      digitalCard: null
    }
  }

  async listCredentials(physicalCardId: string): Promise<Credential[]> {
    return []
  }

  async getCredential(credentialId: string): Promise<Credential | null> {
    return null
  }

  translateCredential(
    authorization: Authorization,
    physicalCardId: string
  ): Credential | null {
    return null
  }

  verifyCredential(
    credential: Credential,
    authorization: Authorization,
    physicalCardId: string
  ): boolean {
    return false
  }

  private failedOperation(operationId: string): OperationReceipt {
    return {
      operationId: operationId,
      state: OperationState.FAILED,
      authority: OperationAuthority.PHYSICAL_CARD,
      verificationRequired: true,
      receiptId: '',
      errorCode: 'cardCProtocolUnavailable',
      updatedAt: new Date().toISOString()
    }
  }
}
