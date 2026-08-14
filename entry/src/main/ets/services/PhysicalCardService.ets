import { PhysicalCard } from '../models/PhysicalCard'
import {
  CredentialRemovalResult,
  CredentialWriteProgressListener,
  CredentialWriteRequest,
  CredentialWriteResult,
  PhysicalCardConnectionResult,
  PhysicalCardDiscoveryListener,
  PrimaryPhysicalCardBindingResult
} from '../models/PhysicalCardOperation'

export interface PhysicalCardService {
  listPhysicalCards(): Promise<PhysicalCard[]>
  getPrimaryPhysicalCard(): Promise<PhysicalCard | null>
  bindPrimaryPhysicalCard(
    physicalCardId: string
  ): Promise<PrimaryPhysicalCardBindingResult>
  getPhysicalCard(physicalCardId: string): Promise<PhysicalCard | null>
  startDiscovery(listener: PhysicalCardDiscoveryListener): void
  stopDiscovery(): void
  connectPhysicalCard(physicalCardId: string): Promise<PhysicalCardConnectionResult>
  disconnectPhysicalCard(physicalCardId: string): Promise<PhysicalCardConnectionResult>
  writeCredential(
    request: CredentialWriteRequest,
    listener: CredentialWriteProgressListener
  ): Promise<CredentialWriteResult>
  cancelCredentialWrite(): void
  removeCredential(credentialId: string): Promise<CredentialRemovalResult>
}
