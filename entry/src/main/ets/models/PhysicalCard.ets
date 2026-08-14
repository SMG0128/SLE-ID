import { CardAnonId } from './DomainIdentifiers'

export enum PhysicalCardStatus {
  AVAILABLE = 'available',
  CAPACITY_FULL = 'capacityFull',
  DEGRADED = 'degraded',
  OFFLINE = 'offline',
  LOST = 'lost',
  REVOKED = 'revoked'
}

export enum PhysicalCardConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  CONNECTION_FAILED = 'connectionFailed',
  DISCONNECTING = 'disconnecting'
}

export enum PhysicalCardDiscoveryState {
  IDLE = 'idle',
  DISCOVERING = 'discovering',
  DISCOVERED = 'discovered',
  NO_DEVICE = 'noDevice',
  DISCOVERY_FAILED = 'discoveryFailed',
  STOPPED = 'stopped'
}

export enum MockPhysicalCardFailureMode {
  NONE = 'none',
  CONNECTION_FAILED = 'connectionFailed',
  CONNECTION_INTERRUPTED = 'connectionInterrupted',
  WRITE_FAILED = 'writeFailed',
  VERIFICATION_FAILED = 'verificationFailed',
  OFFLINE_DURING_WRITE = 'offlineDuringWrite'
}

export enum MockDiscoveryScenario {
  NORMAL = 'normal',
  NO_DEVICE = 'noDevice',
  FAILURE = 'failure'
}

export interface PhysicalCard {
  physicalCardId: string
  cardAnonId: CardAnonId
  displayName: string
  hardwareVersion: string
  firmwareVersion: string
  totalCapacity: number
  usedCapacity: number
  credentialIds: string[]
  connectionState: PhysicalCardConnectionState
  cardStatus: PhysicalCardStatus
  lastSeenAt: string
  lastWrittenAt: string
  mockFailureMode: MockPhysicalCardFailureMode
}
