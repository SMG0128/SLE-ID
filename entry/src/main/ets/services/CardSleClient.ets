import {
  CardCInfo,
  CardCommitAcknowledgement,
  CardCredentialReadback,
  CardWriteAuthorization,
  CardWritePackage,
  CardWriteTarget
} from '../models/CardProvisioning'

// Card C wire command identifiers and packet layouts are intentionally absent.
// The firmware-backed adapter must implement this boundary from its authoritative
// binary contract; the coordinator never sends JSON over SLE.
export interface CardSleClient {
  scanAndSelect(target: CardWriteTarget): Promise<string>
  connect(deviceHandle: string): Promise<void>
  readCardInfo(): Promise<CardCInfo>
  authenticate(authorization: CardWriteAuthorization): Promise<void>
  beginCredential(writePackage: CardWritePackage): Promise<string>
  writeCredentialChunk(
    transactionHandle: string,
    offset: number,
    chunk: Uint8Array
  ): Promise<void>
  commitCredential(
    transactionHandle: string
  ): Promise<CardCommitAcknowledgement>
  listCredentials(): Promise<CardCredentialReadback[]>
  disconnect(): Promise<void>
}
