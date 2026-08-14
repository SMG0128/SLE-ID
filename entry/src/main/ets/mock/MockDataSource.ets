import {
  DigitalCard,
  DigitalCardStatus,
  DigitalCardVisualStyle
} from '../models/DigitalCard'
import {
  Authorization,
  AuthorizationAlertLevel,
  AuthorizationAlertPolicy,
  AuthorizationStatus,
  AuthorizationUsageMode
} from '../models/Authorization'
import {
  MockDiscoveryScenario,
  MockPhysicalCardFailureMode,
  PhysicalCard,
  PhysicalCardConnectionState,
  PhysicalCardDiscoveryState,
  PhysicalCardStatus
} from '../models/PhysicalCard'
import {
  Credential,
  CredentialBindingStatus,
  CredentialCondition,
  CredentialPolicyFlags
} from '../models/Credential'
import {
  CredentialRemovalResult,
  CredentialWriteProgressListener,
  CredentialWriteRequest,
  CredentialWriteResult,
  PhysicalCardConnectionResult,
  PhysicalCardDiscoveryListener,
  PhysicalCardDiscoveryUpdate,
  PhysicalCardFailureReason,
  PrimaryPhysicalCardBindingResult
} from '../models/PhysicalCardOperation'
import {
  cloneConfirmationRequest,
  ConfirmationRequest,
  ConfirmationRequestStatus,
  ConfirmationTransitionResult,
  transitionConfirmationRequest
} from '../models/ConfirmationRequest'
import {
  InvitationAuthorizationPreview,
  InvitationFailureReason,
  InvitationFlowState,
  InvitationMockStatus,
  InvitationPreviewResult,
  InvitationRedemptionResult,
  MockInvitation
} from '../models/Invitation'
import { DigitalCardService } from '../services/DigitalCardService'
import { AuthorizationService } from '../services/AuthorizationService'
import { PhysicalCardService } from '../services/PhysicalCardService'
import { CredentialService } from '../services/CredentialService'
import { ConfirmationService } from '../services/ConfirmationService'
import { InvitationService } from '../services/InvitationService'
import { MockPersistenceService } from '../services/MockPersistenceService'
import { MockAppStoragePersistence } from './MockAppStoragePersistence'
import {
  OperationAuthority,
  OperationReceipt,
  OperationState
} from '../models/Operation'
import { createLocalSyncState } from '../models/SyncState'

interface MockDigitalCardBindingState {
  digitalCardId: string
  credentialId: string
  physicalCardId: string
  credentialBindingStatus: CredentialBindingStatus
  credentialCondition: CredentialCondition
}

interface MockPhysicalCardPersistenceState {
  physicalCards: PhysicalCard[]
  credentials: Credential[]
  bindings: MockDigitalCardBindingState[]
  primaryPhysicalCardId: string
}

export class MockDataSource implements
  DigitalCardService,
  AuthorizationService,
  PhysicalCardService,
  CredentialService,
  ConfirmationService,
  InvitationService {
  private static instance: MockDataSource
  private persistenceService: MockPersistenceService
  private discoveryTimer: number = -1
  private discoveryListener: PhysicalCardDiscoveryListener | null = null
  private discoveryScenario: MockDiscoveryScenario = MockDiscoveryScenario.NORMAL
  private writeOperationId: number = 0
  private writeInProgress: boolean = false
  private connectionOperationId: number = 0
  private primaryPhysicalCardId: string = 'ws63-normal'

  private digitalCards: DigitalCard[] = [
    {
      id: '1',
      name: 'Identity Card',
      issuer: 'SleKey Identity Services',
      cardAnonId: '882011047312',
      anonymousNumber: '8820 1104 7312',
      nickname: 'My Identity',
      detail: 'Digital identification',
      category: 'Identity',
      status: DigitalCardStatus.ACTIVE,
      visualStyle: DigitalCardVisualStyle.IDENTITY,
      permissionId: 'authorization-identity',
      credentialId: 'credential-identity',
      physicalCardId: 'ws63-normal',
      credentialBindingStatus: CredentialBindingStatus.ACTIVE,
      credentialCondition: CredentialCondition.ACTIVE,
      adminConfirmRequired: false,
      userConfirmationEnabled: true,
      allowTemporaryPass: true,
      validFrom: '2026-01-01T00:00:00+08:00',
      validUntil: '2027-01-01T00:00:00+08:00',
      syncState: createLocalSyncState('2026-07-26T20:00:00+08:00')
    },
    {
      id: '2',
      name: 'MTR Ticket',
      issuer: 'Hong Kong Transport',
      cardAnonId: '002145214422',
      anonymousNumber: '0021 4521 4422',
      nickname: 'Metro',
      detail: 'Ticket pass for MTR',
      category: 'Traffic',
      status: DigitalCardStatus.ACTIVE,
      visualStyle: DigitalCardVisualStyle.TRANSIT,
      permissionId: 'authorization-transit',
      credentialId: 'credential-transit',
      physicalCardId: 'ws63-normal',
      credentialBindingStatus: CredentialBindingStatus.ACTIVE,
      credentialCondition: CredentialCondition.ACTIVE,
      adminConfirmRequired: true,
      userConfirmationEnabled: false,
      allowTemporaryPass: true,
      validFrom: '2026-01-01T00:00:00+08:00',
      validUntil: '2026-12-31T23:59:59+08:00',
      syncState: createLocalSyncState('2026-07-26T20:00:00+08:00')
    },
    {
      id: '3',
      name: 'Access Key',
      issuer: 'SleKey Workplace',
      cardAnonId: '410876210096',
      anonymousNumber: '4108 7621 0096',
      nickname: 'Office',
      detail: 'Smart office entry',
      category: 'Access',
      status: DigitalCardStatus.ACTIVE,
      visualStyle: DigitalCardVisualStyle.ACCESS,
      permissionId: 'authorization-access',
      credentialId: '',
      physicalCardId: '',
      credentialBindingStatus: CredentialBindingStatus.NOT_WRITTEN,
      credentialCondition: CredentialCondition.ACTIVE,
      adminConfirmRequired: false,
      userConfirmationEnabled: false,
      allowTemporaryPass: false,
      validFrom: '2026-01-01T00:00:00+08:00',
      validUntil: '2027-01-01T00:00:00+08:00',
      syncState: createLocalSyncState('2026-07-26T20:00:00+08:00')
    }
  ]

  private authorizations: Authorization[] = [
    {
      permissionId: 'authorization-identity',
      digitalCardId: '1',
      organizationId: 'issuer-slekey-identity',
      name: 'Digital Identity',
      issuer: 'SleKey Identity Services',
      status: AuthorizationStatus.ACTIVE,
      scopes: ['identity-verification'],
      validFrom: '2026-01-01T00:00:00+08:00',
      validUntil: '2027-01-01T00:00:00+08:00',
      usageMode: AuthorizationUsageMode.UNLIMITED,
      usageLimit: 0,
      remainingUses: 0,
      adminConfirmRequired: false,
      phoneSubstituteAllowed: true,
      alertPolicy: AuthorizationAlertPolicy.NOTIFY_ON_USE,
      recordEvent: true,
      allowExecution: true,
      alertOnUnauthorized: true,
      alertLevel: AuthorizationAlertLevel.WARNING,
      offlineAllowed: true,
      directionDetection: false,
      policyVersion: 'mock-policy-v1',
      syncState: createLocalSyncState('2026-07-26T20:00:00+08:00')
    },
    {
      permissionId: 'authorization-transit',
      digitalCardId: '2',
      organizationId: 'issuer-hk-transport',
      name: 'MTR Access',
      issuer: 'Hong Kong Transport',
      status: AuthorizationStatus.ACTIVE,
      scopes: ['mtr-network'],
      validFrom: '2026-01-01T00:00:00+08:00',
      validUntil: '2026-12-31T23:59:59+08:00',
      usageMode: AuthorizationUsageMode.UNLIMITED,
      usageLimit: 0,
      remainingUses: 0,
      adminConfirmRequired: true,
      phoneSubstituteAllowed: true,
      alertPolicy: AuthorizationAlertPolicy.HIGH_ATTENTION,
      recordEvent: true,
      allowExecution: true,
      alertOnUnauthorized: true,
      alertLevel: AuthorizationAlertLevel.CRITICAL,
      offlineAllowed: false,
      directionDetection: true,
      policyVersion: 'mock-policy-v1',
      syncState: createLocalSyncState('2026-07-26T20:00:00+08:00')
    },
    {
      permissionId: 'authorization-access',
      digitalCardId: '3',
      organizationId: 'issuer-slekey-workplace',
      name: 'Office Access',
      issuer: 'SleKey Workplace',
      status: AuthorizationStatus.ACTIVE,
      scopes: ['office-main-entrance'],
      validFrom: '2026-01-01T00:00:00+08:00',
      validUntil: '2027-01-01T00:00:00+08:00',
      usageMode: AuthorizationUsageMode.UNLIMITED,
      usageLimit: 0,
      remainingUses: 0,
      adminConfirmRequired: false,
      phoneSubstituteAllowed: false,
      alertPolicy: AuthorizationAlertPolicy.DEFAULT,
      recordEvent: true,
      allowExecution: true,
      alertOnUnauthorized: false,
      alertLevel: AuthorizationAlertLevel.INFO,
      offlineAllowed: true,
      directionDetection: false,
      policyVersion: 'mock-policy-v1',
      syncState: createLocalSyncState('2026-07-26T20:00:00+08:00')
    }
  ]

  private physicalCards: PhysicalCard[] = [
    {
      physicalCardId: 'ws63-normal',
      cardAnonId: 'MOCK-WS63-****-1001',
      displayName: 'Daily WS63',
      hardwareVersion: 'WS63-MOCK-HW-A1',
      firmwareVersion: 'MOCK-FW-2.1.0',
      totalCapacity: 6,
      usedCapacity: 2,
      credentialIds: ['credential-identity', 'credential-transit'],
      connectionState: PhysicalCardConnectionState.DISCONNECTED,
      cardStatus: PhysicalCardStatus.AVAILABLE,
      lastSeenAt: '2026-07-26T19:55:00+08:00',
      lastWrittenAt: '2026-07-10T12:00:00+08:00',
      mockFailureMode: MockPhysicalCardFailureMode.NONE
    },
    {
      physicalCardId: 'ws63-full',
      cardAnonId: 'MOCK-WS63-****-2002',
      displayName: 'Full WS63',
      hardwareVersion: 'WS63-MOCK-HW-A1',
      firmwareVersion: 'MOCK-FW-2.0.4',
      totalCapacity: 0,
      usedCapacity: 0,
      credentialIds: [],
      connectionState: PhysicalCardConnectionState.DISCONNECTED,
      cardStatus: PhysicalCardStatus.CAPACITY_FULL,
      lastSeenAt: '2026-07-26T19:55:00+08:00',
      lastWrittenAt: '2026-07-12T12:00:00+08:00',
      mockFailureMode: MockPhysicalCardFailureMode.NONE
    },
    {
      physicalCardId: 'ws63-connect-error',
      cardAnonId: 'MOCK-WS63-****-3003',
      displayName: 'Connection Error WS63',
      hardwareVersion: 'WS63-MOCK-HW-B1',
      firmwareVersion: 'MOCK-FW-1.9.0',
      totalCapacity: 4,
      usedCapacity: 0,
      credentialIds: [],
      connectionState: PhysicalCardConnectionState.DISCONNECTED,
      cardStatus: PhysicalCardStatus.DEGRADED,
      lastSeenAt: '2026-07-26T19:55:00+08:00',
      lastWrittenAt: '',
      mockFailureMode: MockPhysicalCardFailureMode.CONNECTION_FAILED
    },
    {
      physicalCardId: 'ws63-write-error',
      cardAnonId: 'MOCK-WS63-****-4004',
      displayName: 'Write Error WS63',
      hardwareVersion: 'WS63-MOCK-HW-B1',
      firmwareVersion: 'MOCK-FW-1.9.1',
      totalCapacity: 4,
      usedCapacity: 0,
      credentialIds: [],
      connectionState: PhysicalCardConnectionState.DISCONNECTED,
      cardStatus: PhysicalCardStatus.DEGRADED,
      lastSeenAt: '2026-07-26T19:55:00+08:00',
      lastWrittenAt: '',
      mockFailureMode: MockPhysicalCardFailureMode.WRITE_FAILED
    },
    {
      physicalCardId: 'ws63-verify-error',
      cardAnonId: 'MOCK-WS63-****-5005',
      displayName: 'Verification Error WS63',
      hardwareVersion: 'WS63-MOCK-HW-B1',
      firmwareVersion: 'MOCK-FW-1.9.1',
      totalCapacity: 4,
      usedCapacity: 0,
      credentialIds: [],
      connectionState: PhysicalCardConnectionState.DISCONNECTED,
      cardStatus: PhysicalCardStatus.DEGRADED,
      lastSeenAt: '2026-07-26T19:55:00+08:00',
      lastWrittenAt: '',
      mockFailureMode: MockPhysicalCardFailureMode.VERIFICATION_FAILED
    },
    {
      physicalCardId: 'ws63-offline-error',
      cardAnonId: 'MOCK-WS63-****-6006',
      displayName: 'Offline During Write WS63',
      hardwareVersion: 'WS63-MOCK-HW-B1',
      firmwareVersion: 'MOCK-FW-1.9.1',
      totalCapacity: 4,
      usedCapacity: 0,
      credentialIds: [],
      connectionState: PhysicalCardConnectionState.DISCONNECTED,
      cardStatus: PhysicalCardStatus.DEGRADED,
      lastSeenAt: '2026-07-26T19:55:00+08:00',
      lastWrittenAt: '',
      mockFailureMode: MockPhysicalCardFailureMode.OFFLINE_DURING_WRITE
    }
  ]

  private credentials: Credential[] = [
    {
      credentialId: 'credential-identity',
      permissionId: 'authorization-identity',
      organizationId: 'issuer-slekey-identity',
      physicalCardId: 'ws63-normal',
      protocolVersion: 'SLEKEY-MOCK-1',
      credentialVersion: 1,
      policyVersion: 'mock-policy-v1',
      permissionScopeDigest: 'mock-digest-identity',
      policyFlags: {
        recordEvent: true,
        allowExecution: true,
        adminConfirmRequired: false,
        alertOnUnauthorized: true,
        alertLevel: AuthorizationAlertLevel.WARNING,
        offlineAllowed: true,
        phoneSubstituteAllowed: true,
        directionDetection: false
      },
      validFrom: '2026-01-01T00:00:00+08:00',
      validUntil: '2027-01-01T00:00:00+08:00',
      keyVersion: 1,
      mockAuthenticationMaterial: 'MOCK-ONLY-AUTH-IDENTITY',
      integrityCheck: 'mock-integrity-identity',
      bindingStatus: CredentialBindingStatus.ACTIVE,
      condition: CredentialCondition.ACTIVE,
      writtenAt: '2026-07-10T12:00:00+08:00',
      verifiedAt: '2026-07-10T12:00:01+08:00'
    },
    {
      credentialId: 'credential-transit',
      permissionId: 'authorization-transit',
      organizationId: 'issuer-hk-transport',
      physicalCardId: 'ws63-normal',
      protocolVersion: 'SLEKEY-MOCK-1',
      credentialVersion: 1,
      policyVersion: 'mock-policy-v1',
      permissionScopeDigest: 'mock-digest-transit',
      policyFlags: {
        recordEvent: true,
        allowExecution: true,
        adminConfirmRequired: true,
        alertOnUnauthorized: true,
        alertLevel: AuthorizationAlertLevel.CRITICAL,
        offlineAllowed: false,
        phoneSubstituteAllowed: true,
        directionDetection: true
      },
      validFrom: '2026-01-01T00:00:00+08:00',
      validUntil: '2026-12-31T23:59:59+08:00',
      keyVersion: 1,
      mockAuthenticationMaterial: 'MOCK-ONLY-AUTH-TRANSIT',
      integrityCheck: 'mock-integrity-transit',
      bindingStatus: CredentialBindingStatus.ACTIVE,
      condition: CredentialCondition.ACTIVE,
      writtenAt: '2026-07-10T12:00:00+08:00',
      verifiedAt: '2026-07-10T12:00:01+08:00'
    }
  ]

  private confirmationRequests: ConfirmationRequest[] = []

  private invitations: MockInvitation[] = [
    {
      code: 'SLE-DEMO-2026',
      status: InvitationMockStatus.AVAILABLE,
      preview: {
        permissionId: 'authorization-visitor-demo',
        organizationId: 'issuer-slekey-visitor',
        issuerName: 'SleKey Visitor Services',
        cardName: 'Visitor Pass',
        cardDescription: 'Temporary visitor access authorization',
        permissionScope: ['园区南门', '访客中心', 'A 栋公共区域'],
        validFrom: '2026-07-26T00:00:00+08:00',
        validUntil: '2026-12-31T23:59:59+08:00',
        usageMode: AuthorizationUsageMode.LIMITED,
        usageLimit: 20,
        adminConfirmRequired: true,
        policyVersion: 'mock-policy-v1',
        phoneSubstituteAllowed: true,
        alertPolicy: AuthorizationAlertPolicy.HIGH_ATTENTION,
        recordEvent: true,
        allowExecution: true,
        alertOnUnauthorized: true,
        alertLevel: AuthorizationAlertLevel.CRITICAL,
        offlineAllowed: false,
        directionDetection: true,
        cardAppearance: DigitalCardVisualStyle.ACCESS,
        category: 'Visitor'
      }
    },
    {
      code: 'SLE-LAB2-2026',
      status: InvitationMockStatus.AVAILABLE,
      preview: {
        permissionId: 'authorization-lab-demo',
        organizationId: 'issuer-slekey-lab',
        issuerName: 'SleKey Lab Services',
        cardName: 'Lab Access',
        cardDescription: 'Second Mock authorization for multi-credential tests',
        permissionScope: ['lab-entry', 'shared-equipment'],
        validFrom: '2026-07-26T00:00:00+08:00',
        validUntil: '2027-07-26T00:00:00+08:00',
        usageMode: AuthorizationUsageMode.UNLIMITED,
        usageLimit: 0,
        adminConfirmRequired: false,
        policyVersion: 'mock-policy-v1',
        phoneSubstituteAllowed: false,
        alertPolicy: AuthorizationAlertPolicy.NOTIFY_ON_USE,
        recordEvent: true,
        allowExecution: true,
        alertOnUnauthorized: true,
        alertLevel: AuthorizationAlertLevel.WARNING,
        offlineAllowed: true,
        directionDetection: true,
        cardAppearance: DigitalCardVisualStyle.ACCESS,
        category: 'Lab'
      }
    },
    {
      code: 'SLE-EXPD-2026',
      status: InvitationMockStatus.EXPIRED,
      preview: {
        permissionId: 'authorization-expired-demo',
        organizationId: 'issuer-slekey-event',
        issuerName: 'SleKey Event Services',
        cardName: 'Expired Event Pass',
        cardDescription: 'Expired event authorization',
        permissionScope: ['活动会场'],
        validFrom: '2025-01-01T00:00:00+08:00',
        validUntil: '2025-12-31T23:59:59+08:00',
        usageMode: AuthorizationUsageMode.LIMITED,
        usageLimit: 1,
        adminConfirmRequired: false,
        policyVersion: 'mock-policy-v1',
        phoneSubstituteAllowed: false,
        alertPolicy: AuthorizationAlertPolicy.DEFAULT,
        recordEvent: true,
        allowExecution: true,
        alertOnUnauthorized: false,
        alertLevel: AuthorizationAlertLevel.INFO,
        offlineAllowed: false,
        directionDetection: false,
        cardAppearance: DigitalCardVisualStyle.IDENTITY,
        category: 'Event'
      }
    },
    {
      code: 'SLE-USED-2026',
      status: InvitationMockStatus.USED,
      preview: {
        permissionId: 'authorization-used-demo',
        organizationId: 'issuer-slekey-demo',
        issuerName: 'SleKey Demo Services',
        cardName: 'Used Invitation Pass',
        cardDescription: 'Invitation already consumed by another redemption',
        permissionScope: ['演示区域'],
        validFrom: '2026-01-01T00:00:00+08:00',
        validUntil: '2027-01-01T00:00:00+08:00',
        usageMode: AuthorizationUsageMode.UNLIMITED,
        usageLimit: 0,
        adminConfirmRequired: false,
        policyVersion: 'mock-policy-v1',
        phoneSubstituteAllowed: true,
        alertPolicy: AuthorizationAlertPolicy.NOTIFY_ON_USE,
        recordEvent: true,
        allowExecution: true,
        alertOnUnauthorized: true,
        alertLevel: AuthorizationAlertLevel.WARNING,
        offlineAllowed: true,
        directionDetection: false,
        cardAppearance: DigitalCardVisualStyle.TRANSIT,
        category: 'Demo'
      }
    },
    {
      code: 'SLE-BOND-2026',
      status: InvitationMockStatus.AVAILABLE,
      preview: {
        permissionId: 'authorization-identity',
        organizationId: 'issuer-slekey-identity',
        issuerName: 'SleKey Identity Services',
        cardName: 'Identity Card',
        cardDescription: 'Authorization already present in the wallet',
        permissionScope: ['identity-verification'],
        validFrom: '2026-01-01T00:00:00+08:00',
        validUntil: '2027-01-01T00:00:00+08:00',
        usageMode: AuthorizationUsageMode.UNLIMITED,
        usageLimit: 0,
        adminConfirmRequired: false,
        policyVersion: 'mock-policy-v1',
        phoneSubstituteAllowed: true,
        alertPolicy: AuthorizationAlertPolicy.NOTIFY_ON_USE,
        recordEvent: true,
        allowExecution: true,
        alertOnUnauthorized: true,
        alertLevel: AuthorizationAlertLevel.WARNING,
        offlineAllowed: true,
        directionDetection: false,
        cardAppearance: DigitalCardVisualStyle.IDENTITY,
        category: 'Identity'
      }
    },
    {
      code: 'SLE-FAIL-2026',
      status: InvitationMockStatus.REQUEST_ERROR,
      preview: {
        permissionId: 'authorization-error-demo',
        organizationId: 'issuer-slekey-error',
        issuerName: 'SleKey Error Simulation',
        cardName: 'Unavailable Pass',
        cardDescription: 'Mock request error simulation',
        permissionScope: ['不可用区域'],
        validFrom: '2026-01-01T00:00:00+08:00',
        validUntil: '2027-01-01T00:00:00+08:00',
        usageMode: AuthorizationUsageMode.UNLIMITED,
        usageLimit: 0,
        adminConfirmRequired: false,
        policyVersion: 'mock-policy-v1',
        phoneSubstituteAllowed: false,
        alertPolicy: AuthorizationAlertPolicy.DEFAULT,
        recordEvent: false,
        allowExecution: false,
        alertOnUnauthorized: false,
        alertLevel: AuthorizationAlertLevel.NONE,
        offlineAllowed: false,
        directionDetection: false,
        cardAppearance: DigitalCardVisualStyle.ACCESS,
        category: 'Unavailable'
      }
    }
  ]

  private constructor(persistenceService: MockPersistenceService) {
    this.persistenceService = persistenceService
    this.restoreConsumedInvitations()
    this.restorePhysicalCardState()
  }

  static getInstance(): MockDataSource {
    if (!MockDataSource.instance) {
      MockDataSource.instance = new MockDataSource(new MockAppStoragePersistence())
    }
    return MockDataSource.instance
  }

  static createForTesting(persistenceService: MockPersistenceService): MockDataSource {
    return new MockDataSource(persistenceService)
  }

  getCardSnapshot(): DigitalCard[] {
    return this.cloneCards(this.digitalCards)
  }

  getAuthorizationSnapshot(): Authorization[] {
    return this.authorizations.slice()
  }

  getPhysicalCardSnapshot(): PhysicalCard[] {
    const primaryCard: PhysicalCard | null =
      this.findPhysicalCard(this.primaryPhysicalCardId)
    return primaryCard ? [this.clonePhysicalCard(primaryCard)] : []
  }

  getCredentialSnapshot(): Credential[] {
    return this.cloneCredentials(this.credentials.filter((credential: Credential) =>
      credential.physicalCardId === this.primaryPhysicalCardId &&
      credential.bindingStatus === CredentialBindingStatus.WRITTEN))
  }

  async listDigitalCards(): Promise<DigitalCard[]> {
    return this.cloneCards(this.digitalCards)
  }

  async getDigitalCard(cardId: string): Promise<DigitalCard | null> {
    let result: DigitalCard | null = null
    this.digitalCards.forEach((card: DigitalCard) => {
      if (card.id === cardId) {
        result = this.cloneCard(card)
      }
    })
    return result
  }

  async saveDigitalCard(card: DigitalCard): Promise<DigitalCard> {
    let existingIndex: number = -1
    this.digitalCards.forEach((item: DigitalCard, index: number) => {
      if (item.id === card.id) {
        existingIndex = index
      }
    })

    const savedCard: DigitalCard = this.cloneCard(card)
    if (existingIndex >= 0) {
      this.digitalCards[existingIndex] = savedCard
    } else {
      this.digitalCards.push(savedCard)
    }
    this.digitalCards = this.digitalCards.slice()
    return this.cloneCard(savedCard)
  }

  async removeDigitalCard(cardId: string): Promise<void> {
    this.digitalCards = this.digitalCards.filter((card: DigitalCard) => card.id !== cardId)
  }

  async listAllAuthorizations(): Promise<Authorization[]> {
    return this.authorizations.slice()
  }

  async listAuthorizations(digitalCardId: string): Promise<Authorization[]> {
    return this.authorizations.filter((authorization: Authorization) =>
      authorization.digitalCardId === digitalCardId)
  }

  async getAuthorization(authorizationId: string): Promise<Authorization | null> {
    let result: Authorization | null = null
    this.authorizations.forEach((authorization: Authorization) => {
      if (authorization.permissionId === authorizationId) {
        result = authorization
      }
    })
    return result
  }

  async listPhysicalCards(): Promise<PhysicalCard[]> {
    const primaryCard: PhysicalCard | null =
      this.findPhysicalCard(this.primaryPhysicalCardId)
    return primaryCard ? [this.clonePhysicalCard(primaryCard)] : []
  }

  async getPrimaryPhysicalCard(): Promise<PhysicalCard | null> {
    const primaryCard: PhysicalCard | null =
      this.findPhysicalCard(this.primaryPhysicalCardId)
    return primaryCard ? this.clonePhysicalCard(primaryCard) : null
  }

  async bindPrimaryPhysicalCard(
    physicalCardId: string
  ): Promise<PrimaryPhysicalCardBindingResult> {
    const card: PhysicalCard | null = this.findPhysicalCard(physicalCardId)
    if (!card) {
      return {
        success: false,
        reason: PhysicalCardFailureReason.NOT_FOUND,
        card: null
      }
    }
    const nextDigitalCards: DigitalCard[] = this.cloneCards(this.digitalCards)
    nextDigitalCards.forEach((digitalCard: DigitalCard) => {
      if (digitalCard.physicalCardId === physicalCardId &&
        digitalCard.credentialId.length > 0) {
        digitalCard.credentialBindingStatus = CredentialBindingStatus.ACTIVE
        digitalCard.credentialCondition = CredentialCondition.ACTIVE
      } else if (digitalCard.physicalCardId === this.primaryPhysicalCardId &&
        this.primaryPhysicalCardId !== physicalCardId &&
        digitalCard.credentialBindingStatus === CredentialBindingStatus.WRITTEN) {
        digitalCard.credentialBindingStatus = CredentialBindingStatus.NOT_WRITTEN
        digitalCard.credentialCondition = CredentialCondition.UPDATE_REQUIRED
      }
    })
    try {
      this.persistenceService.savePhysicalCardState(
        this.serializePhysicalCardState(
          this.physicalCards,
          this.credentials,
          nextDigitalCards,
          physicalCardId
        )
      )
    } catch (error) {
      return {
        success: false,
        reason: PhysicalCardFailureReason.PERSISTENCE_FAILED,
        card: null
      }
    }
    this.digitalCards = nextDigitalCards
    this.primaryPhysicalCardId = physicalCardId
    return {
      success: true,
      reason: PhysicalCardFailureReason.NONE,
      card: this.clonePhysicalCard(card)
    }
  }

  async getPhysicalCard(physicalCardId: string): Promise<PhysicalCard | null> {
    const card: PhysicalCard | null = this.findPhysicalCard(physicalCardId)
    return card ? this.clonePhysicalCard(card) : null
  }

  startDiscovery(listener: PhysicalCardDiscoveryListener): void {
    this.discoveryListener = listener
    if (this.discoveryTimer >= 0) {
      listener(this.createDiscoveryUpdate(
        PhysicalCardDiscoveryState.DISCOVERING,
        []
      ))
      return
    }

    listener(this.createDiscoveryUpdate(
      PhysicalCardDiscoveryState.DISCOVERING,
      []
    ))
    this.discoveryTimer = setTimeout(() => {
      this.discoveryTimer = -1
      if (!this.discoveryListener) {
        return
      }
      if (this.discoveryScenario === MockDiscoveryScenario.FAILURE) {
        this.discoveryListener(this.createDiscoveryUpdate(
          PhysicalCardDiscoveryState.DISCOVERY_FAILED,
          []
        ))
        return
      }
      if (this.discoveryScenario === MockDiscoveryScenario.NO_DEVICE) {
        this.discoveryListener(this.createDiscoveryUpdate(
          PhysicalCardDiscoveryState.NO_DEVICE,
          []
        ))
        return
      }
      this.discoveryListener(this.createDiscoveryUpdate(
        PhysicalCardDiscoveryState.DISCOVERED,
        this.physicalCards
      ))
    }, 450)
  }

  stopDiscovery(): void {
    if (this.discoveryTimer >= 0) {
      clearTimeout(this.discoveryTimer)
      this.discoveryTimer = -1
    }
    if (this.discoveryListener) {
      this.discoveryListener(this.createDiscoveryUpdate(
        PhysicalCardDiscoveryState.STOPPED,
        []
      ))
    }
    this.discoveryListener = null
  }

  setDiscoveryScenarioForTesting(scenario: MockDiscoveryScenario): void {
    this.discoveryScenario = scenario
  }

  async connectPhysicalCard(
    physicalCardId: string
  ): Promise<PhysicalCardConnectionResult> {
    const card: PhysicalCard | null = this.findPhysicalCard(physicalCardId)
    if (!card) {
      return this.createConnectionResult(
        PhysicalCardConnectionState.CONNECTION_FAILED,
        PhysicalCardFailureReason.NOT_FOUND,
        null
      )
    }

    const operationId: number = ++this.connectionOperationId
    card.connectionState = PhysicalCardConnectionState.CONNECTING
    await this.delay(260)
    if (operationId !== this.connectionOperationId) {
      card.connectionState = PhysicalCardConnectionState.DISCONNECTED
      return this.createConnectionResult(
        PhysicalCardConnectionState.CONNECTION_FAILED,
        PhysicalCardFailureReason.CONNECTION_INTERRUPTED,
        card
      )
    }
    if (card.mockFailureMode === MockPhysicalCardFailureMode.CONNECTION_FAILED) {
      card.connectionState = PhysicalCardConnectionState.CONNECTION_FAILED
      return this.createConnectionResult(
        card.connectionState,
        PhysicalCardFailureReason.CONNECTION_FAILED,
        card
      )
    }
    if (card.mockFailureMode === MockPhysicalCardFailureMode.CONNECTION_INTERRUPTED) {
      card.connectionState = PhysicalCardConnectionState.DISCONNECTED
      return this.createConnectionResult(
        PhysicalCardConnectionState.CONNECTION_FAILED,
        PhysicalCardFailureReason.CONNECTION_INTERRUPTED,
        card
      )
    }

    card.connectionState = PhysicalCardConnectionState.CONNECTED
    card.lastSeenAt = this.mockNow()
    return this.createConnectionResult(
      card.connectionState,
      PhysicalCardFailureReason.NONE,
      card
    )
  }

  async disconnectPhysicalCard(
    physicalCardId: string
  ): Promise<PhysicalCardConnectionResult> {
    const card: PhysicalCard | null = this.findPhysicalCard(physicalCardId)
    if (!card) {
      return this.createConnectionResult(
        PhysicalCardConnectionState.CONNECTION_FAILED,
        PhysicalCardFailureReason.NOT_FOUND,
        null
      )
    }
    this.connectionOperationId++
    card.connectionState = PhysicalCardConnectionState.DISCONNECTING
    await this.delay(120)
    card.connectionState = PhysicalCardConnectionState.DISCONNECTED
    return this.createConnectionResult(
      card.connectionState,
      PhysicalCardFailureReason.NONE,
      card
    )
  }

  async listCredentials(physicalCardId: string): Promise<Credential[]> {
    return this.cloneCredentials(this.credentials.filter((credential: Credential) =>
      credential.physicalCardId === physicalCardId &&
      credential.bindingStatus === CredentialBindingStatus.WRITTEN))
  }

  async getCredential(credentialId: string): Promise<Credential | null> {
    const credential: Credential | null = this.findCredential(credentialId)
    return credential ? this.cloneCredential(credential) : null
  }

  translateCredential(
    authorization: Authorization,
    physicalCardId: string
  ): Credential | null {
    if (authorization.permissionId.length === 0 ||
      authorization.organizationId.length === 0 ||
      authorization.scopes.length === 0 ||
      physicalCardId.length === 0) {
      return null
    }
    const permissionScopeDigest: string =
      this.mockDigest(authorization.scopes.slice().sort().join('|'))
    const policyFlags: CredentialPolicyFlags = {
      recordEvent: authorization.recordEvent,
      allowExecution: authorization.allowExecution,
      adminConfirmRequired: authorization.adminConfirmRequired,
      alertOnUnauthorized: authorization.alertOnUnauthorized,
      alertLevel: authorization.alertLevel,
      offlineAllowed: authorization.offlineAllowed,
      phoneSubstituteAllowed: authorization.phoneSubstituteAllowed,
      directionDetection: authorization.directionDetection
    }
    const credential: Credential = {
      credentialId: `credential-${authorization.permissionId}-${physicalCardId}`,
      permissionId: authorization.permissionId,
      organizationId: authorization.organizationId,
      physicalCardId: physicalCardId,
      protocolVersion: 'SLEKEY-MOCK-1',
      credentialVersion: 1,
      policyVersion: authorization.policyVersion,
      permissionScopeDigest: permissionScopeDigest,
      policyFlags: policyFlags,
      validFrom: authorization.validFrom,
      validUntil: authorization.validUntil,
      keyVersion: 1,
      mockAuthenticationMaterial:
        `MOCK-ONLY-AUTH-${this.mockDigest(authorization.permissionId).slice(-8)}`,
      integrityCheck: '',
      bindingStatus: CredentialBindingStatus.WRITING,
      condition: CredentialCondition.ACTIVE,
      writtenAt: '',
      verifiedAt: ''
    }
    credential.integrityCheck = this.createCredentialIntegrityCheck(credential)
    return credential
  }

  verifyCredential(
    credential: Credential,
    authorization: Authorization,
    physicalCardId: string
  ): boolean {
    if (credential.credentialId.length === 0 ||
      credential.permissionId !== authorization.permissionId ||
      credential.physicalCardId !== physicalCardId ||
      credential.credentialVersion !== 1) {
      return false
    }
    const expectedDigest: string =
      this.mockDigest(authorization.scopes.slice().sort().join('|'))
    if (credential.permissionScopeDigest !== expectedDigest) {
      return false
    }
    return credential.integrityCheck ===
      this.createCredentialIntegrityCheck(credential)
  }

  async writeCredential(
    request: CredentialWriteRequest,
    listener: CredentialWriteProgressListener
  ): Promise<CredentialWriteResult> {
    if (this.writeInProgress) {
      return this.createWriteResult(
        CredentialBindingStatus.WRITE_FAILED,
        PhysicalCardFailureReason.WRITE_FAILED,
        null,
        null,
        null
      )
    }

    this.writeInProgress = true
    const operationId: number = ++this.writeOperationId
    try {
      const physicalCard: PhysicalCard | null =
        this.findPhysicalCard(request.physicalCardId)
      const authorization: Authorization | null =
        this.findAuthorization(request.permissionId)
      const digitalCard: DigitalCard | null =
        this.findDigitalCard(request.digitalCardId)
      if (!physicalCard || !authorization || !digitalCard) {
        return this.createWriteResult(
          CredentialBindingStatus.WRITE_FAILED,
          PhysicalCardFailureReason.TRANSLATION_FAILED,
          null,
          physicalCard,
          digitalCard
        )
      }
      if (physicalCard.physicalCardId !== this.primaryPhysicalCardId) {
        return this.createWriteResult(
          CredentialBindingStatus.WRITE_FAILED,
          PhysicalCardFailureReason.NOT_FOUND,
          null,
          physicalCard,
          digitalCard
        )
      }
      if (physicalCard.connectionState !== PhysicalCardConnectionState.CONNECTED) {
        return this.createWriteResult(
          CredentialBindingStatus.WRITE_FAILED,
          PhysicalCardFailureReason.NOT_CONNECTED,
          null,
          physicalCard,
          digitalCard
        )
      }
      if (this.hasWrittenAuthorization(physicalCard, authorization.permissionId)) {
        return this.createWriteResult(
          CredentialBindingStatus.ACTIVE,
          PhysicalCardFailureReason.ALREADY_WRITTEN,
          null,
          physicalCard,
          digitalCard
        )
      }
      if (physicalCard.usedCapacity >= physicalCard.totalCapacity) {
        return this.createWriteResult(
          CredentialBindingStatus.WRITE_FAILED,
          PhysicalCardFailureReason.CAPACITY_FULL,
          null,
          physicalCard,
          digitalCard
        )
      }

      const credential: Credential | null =
        this.translateCredential(authorization, physicalCard.physicalCardId)
      if (!credential) {
        return this.persistWriteFailure(
          digitalCard,
          PhysicalCardFailureReason.TRANSLATION_FAILED,
          physicalCard,
          null
        )
      }

      listener(CredentialBindingStatus.WRITING)
      await this.delay(280)
      if (this.isWriteCancelled(operationId)) {
        return this.createWriteResult(
          CredentialBindingStatus.NOT_WRITTEN,
          PhysicalCardFailureReason.CANCELLED,
          null,
          physicalCard,
          digitalCard
        )
      }
      if (physicalCard.mockFailureMode === MockPhysicalCardFailureMode.WRITE_FAILED) {
        credential.bindingStatus = CredentialBindingStatus.WRITE_FAILED
        return this.persistWriteFailure(
          digitalCard,
          PhysicalCardFailureReason.WRITE_FAILED,
          physicalCard,
          credential
        )
      }
      if (physicalCard.mockFailureMode ===
        MockPhysicalCardFailureMode.OFFLINE_DURING_WRITE) {
        physicalCard.connectionState = PhysicalCardConnectionState.DISCONNECTED
        credential.bindingStatus = CredentialBindingStatus.WRITE_FAILED
        return this.persistWriteFailure(
          digitalCard,
          PhysicalCardFailureReason.DEVICE_OFFLINE,
          physicalCard,
          credential
        )
      }

      listener(CredentialBindingStatus.VERIFYING)
      credential.bindingStatus = CredentialBindingStatus.VERIFYING
      await this.delay(280)
      if (this.isWriteCancelled(operationId)) {
        return this.createWriteResult(
          CredentialBindingStatus.NOT_WRITTEN,
          PhysicalCardFailureReason.CANCELLED,
          null,
          physicalCard,
          digitalCard
        )
      }
      const verificationPassed: boolean =
        physicalCard.mockFailureMode !== MockPhysicalCardFailureMode.VERIFICATION_FAILED &&
        this.verifyCredential(credential, authorization, physicalCard.physicalCardId)
      if (!verificationPassed) {
        credential.bindingStatus = CredentialBindingStatus.WRITE_FAILED
        return this.persistWriteFailure(
          digitalCard,
          PhysicalCardFailureReason.VERIFICATION_FAILED,
          physicalCard,
          credential
        )
      }

      const timestamp: string = this.mockNow()
      credential.bindingStatus = CredentialBindingStatus.ACTIVE
      credential.writtenAt = timestamp
      credential.verifiedAt = timestamp

      const nextPhysicalCards: PhysicalCard[] =
        this.clonePhysicalCards(this.physicalCards)
      const nextCredentials: Credential[] =
        this.cloneCredentials(this.credentials)
      const nextDigitalCards: DigitalCard[] =
        this.cloneCards(this.digitalCards)
      const nextPhysicalCard: PhysicalCard | null =
        this.findPhysicalCardIn(nextPhysicalCards, physicalCard.physicalCardId)
      const nextDigitalCard: DigitalCard | null =
        this.findDigitalCardIn(nextDigitalCards, digitalCard.id)
      if (!nextPhysicalCard || !nextDigitalCard) {
        return this.createWriteResult(
          CredentialBindingStatus.WRITE_FAILED,
          PhysicalCardFailureReason.WRITE_FAILED,
          null,
          physicalCard,
          digitalCard
        )
      }
      nextPhysicalCard.credentialIds.push(credential.credentialId)
      nextPhysicalCard.usedCapacity = nextPhysicalCard.credentialIds.length
      nextPhysicalCard.lastWrittenAt = timestamp
      if (nextPhysicalCard.usedCapacity >= nextPhysicalCard.totalCapacity) {
        nextPhysicalCard.cardStatus = PhysicalCardStatus.CAPACITY_FULL
      }
      nextCredentials.push(this.cloneCredential(credential))
      nextDigitalCard.credentialId = credential.credentialId
      nextDigitalCard.physicalCardId = physicalCard.physicalCardId
      nextDigitalCard.credentialBindingStatus = CredentialBindingStatus.ACTIVE
      nextDigitalCard.credentialCondition = CredentialCondition.ACTIVE

      try {
        this.persistenceService.savePhysicalCardState(
          this.serializePhysicalCardState(
            nextPhysicalCards,
            nextCredentials,
            nextDigitalCards
          )
        )
      } catch (error) {
        return this.createWriteResult(
          CredentialBindingStatus.WRITE_FAILED,
          PhysicalCardFailureReason.PERSISTENCE_FAILED,
          null,
          physicalCard,
          digitalCard
        )
      }

      this.physicalCards = nextPhysicalCards
      this.credentials = nextCredentials
      this.digitalCards = nextDigitalCards
      return this.createWriteResult(
        CredentialBindingStatus.ACTIVE,
        PhysicalCardFailureReason.NONE,
        credential,
        nextPhysicalCard,
        nextDigitalCard
      )
    } finally {
      this.writeInProgress = false
    }
  }

  cancelCredentialWrite(): void {
    this.writeOperationId++
  }

  async removeCredential(
    credentialId: string
  ): Promise<CredentialRemovalResult> {
    if (this.writeInProgress) {
      return this.createRemovalResult(
        false,
        PhysicalCardFailureReason.REMOVE_FAILED,
        credentialId,
        null,
        null
      )
    }
    const credential: Credential | null = this.findCredential(credentialId)
    if (!credential) {
      return this.createRemovalResult(
        false,
        PhysicalCardFailureReason.NOT_FOUND,
        credentialId,
        null,
        null
      )
    }
    const physicalCard: PhysicalCard | null =
      this.findPhysicalCard(credential.physicalCardId)
    const digitalCard: DigitalCard | null =
      this.findDigitalCardByAuthorization(credential.permissionId)
    if (!physicalCard ||
      physicalCard.physicalCardId !== this.primaryPhysicalCardId) {
      return this.createRemovalResult(
        false,
        PhysicalCardFailureReason.REMOVE_FAILED,
        credentialId,
        null,
        digitalCard
      )
    }

    const nextPhysicalCards: PhysicalCard[] =
      this.clonePhysicalCards(this.physicalCards)
    const nextCredentials: Credential[] =
      this.cloneCredentials(this.credentials).filter((item: Credential) =>
        item.credentialId !== credentialId)
    const nextDigitalCards: DigitalCard[] =
      this.cloneCards(this.digitalCards)
    const nextPhysicalCard: PhysicalCard | null =
      this.findPhysicalCardIn(nextPhysicalCards, physicalCard.physicalCardId)
    const nextDigitalCard: DigitalCard | null = digitalCard ?
      this.findDigitalCardIn(nextDigitalCards, digitalCard.id) : null
    if (!nextPhysicalCard) {
      return this.createRemovalResult(
        false,
        PhysicalCardFailureReason.REMOVE_FAILED,
        credentialId,
        physicalCard,
        digitalCard
      )
    }

    nextPhysicalCard.credentialIds =
      nextPhysicalCard.credentialIds.filter((id: string) => id !== credentialId)
    nextPhysicalCard.usedCapacity = nextPhysicalCard.credentialIds.length
    if (nextPhysicalCard.cardStatus === PhysicalCardStatus.CAPACITY_FULL &&
      nextPhysicalCard.usedCapacity < nextPhysicalCard.totalCapacity) {
      nextPhysicalCard.cardStatus = PhysicalCardStatus.AVAILABLE
    }
    if (nextDigitalCard) {
      nextDigitalCard.credentialId = ''
      nextDigitalCard.physicalCardId = ''
      nextDigitalCard.credentialBindingStatus = CredentialBindingStatus.NOT_WRITTEN
      nextDigitalCard.credentialCondition = CredentialCondition.REMOVED
    }

    try {
      this.persistenceService.savePhysicalCardState(
        this.serializePhysicalCardState(
          nextPhysicalCards,
          nextCredentials,
          nextDigitalCards
        )
      )
    } catch (error) {
      return this.createRemovalResult(
        false,
        PhysicalCardFailureReason.PERSISTENCE_FAILED,
        credentialId,
        physicalCard,
        digitalCard
      )
    }

    this.physicalCards = nextPhysicalCards
    this.credentials = nextCredentials
    this.digitalCards = nextDigitalCards
    return this.createRemovalResult(
      true,
      PhysicalCardFailureReason.NONE,
      credentialId,
      nextPhysicalCard,
      nextDigitalCard
    )
  }

  async listConfirmationRequests(): Promise<ConfirmationRequest[]> {
    const result: ConfirmationRequest[] = []
    this.confirmationRequests.forEach((request: ConfirmationRequest) => {
      result.push(cloneConfirmationRequest(request))
    })
    return result
  }

  async getConfirmationRequest(requestId: string): Promise<ConfirmationRequest | null> {
    let result: ConfirmationRequest | null = null
    this.confirmationRequests.forEach((request: ConfirmationRequest) => {
      if (request.requestId === requestId) {
        result = cloneConfirmationRequest(request)
      }
    })
    return result
  }

  async resolveConfirmation(
    requestId: string,
    status: ConfirmationRequestStatus
  ): Promise<ConfirmationRequest> {
    let requestIndex: number = -1
    this.confirmationRequests.forEach((request: ConfirmationRequest, index: number) => {
      if (request.requestId === requestId) {
        requestIndex = index
      }
    })
    if (requestIndex < 0) {
      throw new Error('Mock confirmation request not found')
    }
    const transition: ConfirmationTransitionResult =
      transitionConfirmationRequest(
        this.confirmationRequests[requestIndex],
        status,
        this.mockNow()
      )
    this.confirmationRequests[requestIndex] = transition.request
    this.confirmationRequests = this.confirmationRequests.slice()
    return cloneConfirmationRequest(this.confirmationRequests[requestIndex])
  }

  addConfirmationRequestForTesting(request: ConfirmationRequest): void {
    this.confirmationRequests.push(cloneConfirmationRequest(request))
    this.confirmationRequests = this.confirmationRequests.slice()
  }

  validateInvitationFormat(code: string): boolean {
    const normalizedCode: string = this.normalizeInvitationCode(code)
    if (normalizedCode.length !== 13 ||
      normalizedCode.substring(0, 4) !== 'SLE-' ||
      normalizedCode.charAt(8) !== '-') {
      return false
    }

    for (let index: number = 4; index < normalizedCode.length; index++) {
      if (index === 8) {
        continue
      }
      if (!this.isInvitationCodeCharacter(normalizedCode.charAt(index))) {
        return false
      }
    }
    return true
  }

  async previewInvitation(code: string): Promise<InvitationPreviewResult> {
    return this.evaluateInvitation(code)
  }

  async redeemInvitation(code: string): Promise<InvitationRedemptionResult> {
    const normalizedCode: string = this.normalizeInvitationCode(code)
    const previewResult: InvitationPreviewResult = this.evaluateInvitation(normalizedCode)
    if (previewResult.state !== InvitationFlowState.PREVIEW_READY || !previewResult.preview) {
      return this.createRedemptionResult(
        previewResult.state,
        previewResult.reason,
        previewResult.preview,
        null,
        null
      )
    }

    const invitation: MockInvitation | null = this.findInvitation(normalizedCode)
    if (!invitation) {
      return this.createRedemptionResult(
        InvitationFlowState.INVALID,
        InvitationFailureReason.NOT_FOUND,
        null,
        null,
        null
      )
    }

    if (this.hasAuthorization(invitation.preview.permissionId)) {
      return this.createRedemptionResult(
        InvitationFlowState.ALREADY_BOUND,
        InvitationFailureReason.ALREADY_BOUND,
        invitation.preview,
        null,
        null
      )
    }

    const authorization: Authorization = this.createAuthorization(invitation.preview)
    const digitalCard: DigitalCard = this.createDigitalCard(invitation.preview)
    const consumedCodes: string[] = this.persistenceService.loadConsumedInvitationCodes()
    if (consumedCodes.indexOf(normalizedCode) < 0) {
      consumedCodes.push(normalizedCode)
    }

    try {
      this.persistenceService.saveConsumedInvitationCodes(consumedCodes)
    } catch (error) {
      return this.createRedemptionResult(
        InvitationFlowState.REQUEST_ERROR,
        InvitationFailureReason.REQUEST_ERROR,
        invitation.preview,
        null,
        null
      )
    }

    invitation.status = InvitationMockStatus.USED
    this.authorizations.push(authorization)
    this.authorizations = this.authorizations.slice()
    this.digitalCards.push(digitalCard)
    this.digitalCards = this.digitalCards.slice()

    return this.createRedemptionResult(
      InvitationFlowState.SUCCESS,
      InvitationFailureReason.NONE,
      invitation.preview,
      authorization,
      digitalCard
    )
  }

  async isInvitationUsed(code: string): Promise<boolean> {
    const invitation: MockInvitation | null = this.findInvitation(this.normalizeInvitationCode(code))
    return invitation !== null && invitation.status === InvitationMockStatus.USED
  }

  async isAuthorizationBound(authorizationId: string): Promise<boolean> {
    return this.hasAuthorization(authorizationId)
  }

  private evaluateInvitation(code: string): InvitationPreviewResult {
    const normalizedCode: string = this.normalizeInvitationCode(code)
    if (!this.validateInvitationFormat(normalizedCode)) {
      return this.createPreviewResult(
        InvitationFlowState.INVALID,
        InvitationFailureReason.FORMAT,
        null
      )
    }

    const invitation: MockInvitation | null = this.findInvitation(normalizedCode)
    if (!invitation) {
      return this.createPreviewResult(
        InvitationFlowState.INVALID,
        InvitationFailureReason.NOT_FOUND,
        null
      )
    }
    if (invitation.status === InvitationMockStatus.REQUEST_ERROR) {
      return this.createPreviewResult(
        InvitationFlowState.REQUEST_ERROR,
        InvitationFailureReason.REQUEST_ERROR,
        null
      )
    }
    if (invitation.status === InvitationMockStatus.EXPIRED) {
      return this.createPreviewResult(
        InvitationFlowState.EXPIRED,
        InvitationFailureReason.EXPIRED,
        invitation.preview
      )
    }
    if (invitation.status === InvitationMockStatus.USED) {
      return this.createPreviewResult(
        InvitationFlowState.ALREADY_USED,
        InvitationFailureReason.ALREADY_USED,
        invitation.preview
      )
    }
    if (this.hasAuthorization(invitation.preview.permissionId)) {
      return this.createPreviewResult(
        InvitationFlowState.ALREADY_BOUND,
        InvitationFailureReason.ALREADY_BOUND,
        invitation.preview
      )
    }
    return this.createPreviewResult(
      InvitationFlowState.PREVIEW_READY,
      InvitationFailureReason.NONE,
      invitation.preview
    )
  }

  private restoreConsumedInvitations(): void {
    const consumedCodes: string[] = this.persistenceService.loadConsumedInvitationCodes()
    consumedCodes.forEach((code: string) => {
      const invitation: MockInvitation | null = this.findInvitation(code)
      if (!invitation) {
        return
      }
      invitation.status = InvitationMockStatus.USED
      if (this.hasAuthorization(invitation.preview.permissionId)) {
        return
      }
      this.authorizations.push(this.createAuthorization(invitation.preview))
      this.digitalCards.push(this.createDigitalCard(invitation.preview))
    })
    this.authorizations = this.authorizations.slice()
    this.digitalCards = this.digitalCards.slice()
  }

  private createAuthorization(preview: InvitationAuthorizationPreview): Authorization {
    const digitalCardId: string = `digital-${preview.permissionId}`
    return {
      permissionId: preview.permissionId,
      digitalCardId: digitalCardId,
      organizationId: preview.organizationId,
      name: preview.cardName,
      issuer: preview.issuerName,
      status: AuthorizationStatus.BOUND,
      scopes: preview.permissionScope.slice(),
      validFrom: preview.validFrom,
      validUntil: preview.validUntil,
      usageMode: preview.usageMode,
      usageLimit: preview.usageLimit,
      remainingUses: preview.usageLimit,
      adminConfirmRequired: preview.adminConfirmRequired,
      phoneSubstituteAllowed: preview.phoneSubstituteAllowed,
      alertPolicy: preview.alertPolicy,
      recordEvent: preview.recordEvent,
      allowExecution: preview.allowExecution,
      alertOnUnauthorized: preview.alertOnUnauthorized,
      alertLevel: preview.alertLevel,
      offlineAllowed: preview.offlineAllowed,
      directionDetection: preview.directionDetection,
      policyVersion: preview.policyVersion,
      syncState: createLocalSyncState('2026-07-26T20:00:00+08:00')
    }
  }

  private createDigitalCard(preview: InvitationAuthorizationPreview): DigitalCard {
    return {
      id: `digital-${preview.permissionId}`,
      name: preview.cardName,
      issuer: preview.issuerName,
      cardAnonId: `MOCK-${preview.permissionId.slice(-8).toUpperCase()}`,
      anonymousNumber: `MOCK 0000 ${preview.permissionId.slice(-4).toUpperCase()}`,
      nickname: preview.cardName,
      detail: preview.cardDescription,
      category: preview.category,
      status: DigitalCardStatus.ACTIVE,
      visualStyle: preview.cardAppearance,
      permissionId: preview.permissionId,
      credentialId: '',
      physicalCardId: '',
      credentialBindingStatus: CredentialBindingStatus.NOT_WRITTEN,
      credentialCondition: CredentialCondition.ACTIVE,
      adminConfirmRequired: preview.adminConfirmRequired,
      userConfirmationEnabled: false,
      allowTemporaryPass: preview.phoneSubstituteAllowed,
      validFrom: preview.validFrom,
      validUntil: preview.validUntil,
      syncState: createLocalSyncState('2026-07-26T20:00:00+08:00')
    }
  }

  private createPreviewResult(
    state: InvitationFlowState,
    reason: InvitationFailureReason,
    preview: InvitationAuthorizationPreview | null
  ): InvitationPreviewResult {
    return {
      state: state,
      reason: reason,
      preview: preview
    }
  }

  private createRedemptionResult(
    state: InvitationFlowState,
    reason: InvitationFailureReason,
    preview: InvitationAuthorizationPreview | null,
    authorization: Authorization | null,
    digitalCard: DigitalCard | null
  ): InvitationRedemptionResult {
    const succeeded: boolean = state === InvitationFlowState.SUCCESS
    return {
      state: state,
      reason: reason,
      operation: this.createOperationReceipt(
        'invite-redeem',
        succeeded,
        OperationAuthority.LOCAL,
        false,
        reason
      ),
      preview: preview,
      authorization: authorization,
      digitalCard: digitalCard
    }
  }

  private findInvitation(code: string): MockInvitation | null {
    let result: MockInvitation | null = null
    this.invitations.forEach((invitation: MockInvitation) => {
      if (invitation.code === code) {
        result = invitation
      }
    })
    return result
  }

  private hasAuthorization(authorizationId: string): boolean {
    let found: boolean = false
    this.authorizations.forEach((authorization: Authorization) => {
      if (authorization.permissionId === authorizationId) {
        found = true
      }
    })
    return found
  }

  private normalizeInvitationCode(code: string): string {
    return code.trim().toUpperCase()
  }

  private isInvitationCodeCharacter(value: string): boolean {
    if (value.length !== 1) {
      return false
    }
    const characterCode: number = value.charCodeAt(0)
    const isNumber: boolean = characterCode >= 48 && characterCode <= 57
    const isUppercaseLetter: boolean = characterCode >= 65 && characterCode <= 90
    return isNumber || isUppercaseLetter
  }

  private createDiscoveryUpdate(
    state: PhysicalCardDiscoveryState,
    cards: PhysicalCard[]
  ): PhysicalCardDiscoveryUpdate {
    return {
      state: state,
      cards: this.clonePhysicalCards(cards)
    }
  }

  private createConnectionResult(
    state: PhysicalCardConnectionState,
    reason: PhysicalCardFailureReason,
    card: PhysicalCard | null
  ): PhysicalCardConnectionResult {
    return {
      state: state,
      reason: reason,
      card: card ? this.clonePhysicalCard(card) : null
    }
  }

  private createWriteResult(
    status: CredentialBindingStatus,
    reason: PhysicalCardFailureReason,
    credential: Credential | null,
    physicalCard: PhysicalCard | null,
    digitalCard: DigitalCard | null
  ): CredentialWriteResult {
    const succeeded: boolean =
      status === CredentialBindingStatus.ACTIVE &&
      (reason === PhysicalCardFailureReason.NONE ||
        reason === PhysicalCardFailureReason.ALREADY_WRITTEN)
    return {
      status: status,
      reason: reason,
      operation: this.createOperationReceipt(
        'credential-write',
        succeeded,
        OperationAuthority.PHYSICAL_CARD,
        true,
        reason
      ),
      credential: credential ? this.cloneCredential(credential) : null,
      physicalCard: physicalCard ? this.clonePhysicalCard(physicalCard) : null,
      digitalCard: digitalCard ? this.cloneCard(digitalCard) : null
    }
  }

  private createRemovalResult(
    success: boolean,
    reason: PhysicalCardFailureReason,
    credentialId: string,
    physicalCard: PhysicalCard | null,
    digitalCard: DigitalCard | null
  ): CredentialRemovalResult {
    return {
      success: success,
      reason: reason,
      operation: this.createOperationReceipt(
        'credential-remove',
        success,
        OperationAuthority.PHYSICAL_CARD,
        false,
        reason
      ),
      credentialId: credentialId,
      physicalCard: physicalCard ? this.clonePhysicalCard(physicalCard) : null,
      digitalCard: digitalCard ? this.cloneCard(digitalCard) : null
    }
  }

  private createOperationReceipt(
    operationType: string,
    succeeded: boolean,
    authority: OperationAuthority,
    verificationRequired: boolean,
    reason: PhysicalCardFailureReason | InvitationFailureReason
  ): OperationReceipt {
    const timestamp: string = this.mockNow()
    return {
      operationId: `${operationType}-${timestamp}-${this.writeOperationId}`,
      state: succeeded ?
        (verificationRequired ? OperationState.VERIFIED :
          OperationState.ACKNOWLEDGED) : OperationState.FAILED,
      authority: authority,
      verificationRequired: verificationRequired,
      receiptId: succeeded ? `mock-receipt-${operationType}-${timestamp}` : '',
      errorCode: succeeded ? '' : reason.toString(),
      updatedAt: timestamp
    }
  }

  private persistWriteFailure(
    digitalCard: DigitalCard,
    reason: PhysicalCardFailureReason,
    physicalCard: PhysicalCard,
    failedCredential: Credential | null
  ): CredentialWriteResult {
    if (digitalCard.credentialBindingStatus === CredentialBindingStatus.WRITTEN) {
      return this.createWriteResult(
        CredentialBindingStatus.WRITE_FAILED,
        reason,
        failedCredential,
        physicalCard,
        digitalCard
      )
    }
    const nextPhysicalCards: PhysicalCard[] =
      this.clonePhysicalCards(this.physicalCards)
    const nextCredentials: Credential[] =
      this.cloneCredentials(this.credentials)
    const nextDigitalCards: DigitalCard[] =
      this.cloneCards(this.digitalCards)
    const nextDigitalCard: DigitalCard | null =
      this.findDigitalCardIn(nextDigitalCards, digitalCard.id)
    if (!nextDigitalCard) {
      return this.createWriteResult(
        CredentialBindingStatus.WRITE_FAILED,
        reason,
        failedCredential,
        physicalCard,
        digitalCard
      )
    }
    nextDigitalCard.credentialId = ''
    nextDigitalCard.physicalCardId = ''
    nextDigitalCard.credentialBindingStatus = CredentialBindingStatus.WRITE_FAILED
    try {
      this.persistenceService.savePhysicalCardState(
        this.serializePhysicalCardState(
          nextPhysicalCards,
          nextCredentials,
          nextDigitalCards
        )
      )
    } catch (error) {
      return this.createWriteResult(
        CredentialBindingStatus.WRITE_FAILED,
        PhysicalCardFailureReason.PERSISTENCE_FAILED,
        failedCredential,
        physicalCard,
        digitalCard
      )
    }
    this.physicalCards = nextPhysicalCards
    this.credentials = nextCredentials
    this.digitalCards = nextDigitalCards
    return this.createWriteResult(
      CredentialBindingStatus.WRITE_FAILED,
      reason,
      failedCredential,
      physicalCard,
      nextDigitalCard
    )
  }

  private hasWrittenAuthorization(
    physicalCard: PhysicalCard,
    authorizationId: string
  ): boolean {
    let found: boolean = false
    physicalCard.credentialIds.forEach((credentialId: string) => {
      const credential: Credential | null = this.findCredential(credentialId)
      if (credential &&
        credential.permissionId === authorizationId &&
        credential.bindingStatus === CredentialBindingStatus.WRITTEN) {
        found = true
      }
    })
    return found
  }

  private isWriteCancelled(operationId: number): boolean {
    return operationId !== this.writeOperationId
  }

  private findPhysicalCard(physicalCardId: string): PhysicalCard | null {
    return this.findPhysicalCardIn(this.physicalCards, physicalCardId)
  }

  private findPhysicalCardIn(
    cards: PhysicalCard[],
    physicalCardId: string
  ): PhysicalCard | null {
    let result: PhysicalCard | null = null
    cards.forEach((card: PhysicalCard) => {
      if (card.physicalCardId === physicalCardId) {
        result = card
      }
    })
    return result
  }

  private findCredential(credentialId: string): Credential | null {
    let result: Credential | null = null
    this.credentials.forEach((credential: Credential) => {
      if (credential.credentialId === credentialId) {
        result = credential
      }
    })
    return result
  }

  private findAuthorization(authorizationId: string): Authorization | null {
    let result: Authorization | null = null
    this.authorizations.forEach((authorization: Authorization) => {
      if (authorization.permissionId === authorizationId) {
        result = authorization
      }
    })
    return result
  }

  private findDigitalCard(digitalCardId: string): DigitalCard | null {
    return this.findDigitalCardIn(this.digitalCards, digitalCardId)
  }

  private findDigitalCardByAuthorization(
    authorizationId: string
  ): DigitalCard | null {
    let result: DigitalCard | null = null
    this.digitalCards.forEach((card: DigitalCard) => {
      if (card.permissionId === authorizationId) {
        result = card
      }
    })
    return result
  }

  private findDigitalCardIn(
    cards: DigitalCard[],
    digitalCardId: string
  ): DigitalCard | null {
    let result: DigitalCard | null = null
    cards.forEach((card: DigitalCard) => {
      if (card.id === digitalCardId) {
        result = card
      }
    })
    return result
  }

  private mockDigest(value: string): string {
    let checksum: number = 17
    for (let index: number = 0; index < value.length; index++) {
      checksum = (checksum * 31 + value.charCodeAt(index)) % 2147483647
    }
    return `mock-digest-v1-${checksum.toString(16)}`
  }

  private createCredentialIntegrityCheck(credential: Credential): string {
    const policy: CredentialPolicyFlags = credential.policyFlags
    const value: string =
      `${credential.credentialId}|${credential.permissionId}|` +
      `${credential.physicalCardId}|${credential.credentialVersion}|` +
      `${credential.permissionScopeDigest}|${credential.validFrom}|` +
      `${credential.validUntil}|${credential.keyVersion}|` +
      `${policy.recordEvent}|${policy.allowExecution}|` +
      `${policy.adminConfirmRequired}|${policy.alertOnUnauthorized}|` +
      `${policy.alertLevel}|${policy.offlineAllowed}|` +
      `${policy.phoneSubstituteAllowed}|${policy.directionDetection}`
    return `mock-integrity-${this.mockDigest(value)}`
  }

  private mockNow(): string {
    return new Date().toISOString()
  }

  private delay(duration: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, duration)
    })
  }

  private serializePhysicalCardState(
    physicalCards: PhysicalCard[],
    credentials: Credential[],
    digitalCards: DigitalCard[],
    primaryPhysicalCardId: string = this.primaryPhysicalCardId
  ): string {
    const bindings: MockDigitalCardBindingState[] = []
    digitalCards.forEach((card: DigitalCard) => {
      bindings.push({
        digitalCardId: card.id,
        credentialId: card.credentialId,
        physicalCardId: card.physicalCardId,
        credentialBindingStatus: card.credentialBindingStatus,
        credentialCondition: card.credentialCondition
      })
    })
    const state: MockPhysicalCardPersistenceState = {
      physicalCards: this.clonePhysicalCards(physicalCards),
      credentials: this.cloneCredentials(credentials),
      bindings: bindings,
      primaryPhysicalCardId: primaryPhysicalCardId
    }
    return JSON.stringify(state)
  }

  private restorePhysicalCardState(): void {
    const serializedState: string =
      this.persistenceService.loadPhysicalCardState()
    if (serializedState.length === 0) {
      return
    }
    try {
      const state: MockPhysicalCardPersistenceState =
        JSON.parse(serializedState) as MockPhysicalCardPersistenceState
      this.primaryPhysicalCardId =
        state.primaryPhysicalCardId || 'ws63-normal'
      this.physicalCards = this.clonePhysicalCards(state.physicalCards)
      this.physicalCards.forEach((card: PhysicalCard) => {
        card.connectionState = PhysicalCardConnectionState.DISCONNECTED
        card.usedCapacity = card.credentialIds.length
      })
      this.credentials = this.cloneCredentials(state.credentials)
      state.bindings.forEach((binding: MockDigitalCardBindingState) => {
        const card: DigitalCard | null =
          this.findDigitalCard(binding.digitalCardId)
        if (!card) {
          return
        }
        card.credentialId = binding.credentialId
        card.physicalCardId = binding.physicalCardId
        card.credentialBindingStatus = binding.credentialBindingStatus
        card.credentialCondition = binding.credentialCondition ||
          CredentialCondition.ACTIVE
      })
      this.digitalCards = this.cloneCards(this.digitalCards)
    } catch (error) {
      console.error('Unable to restore Mock WS63 state')
    }
  }

  private clonePhysicalCards(cards: PhysicalCard[]): PhysicalCard[] {
    const result: PhysicalCard[] = []
    cards.forEach((card: PhysicalCard) => {
      result.push(this.clonePhysicalCard(card))
    })
    return result
  }

  private clonePhysicalCard(card: PhysicalCard): PhysicalCard {
    return {
      physicalCardId: card.physicalCardId,
      cardAnonId: card.cardAnonId,
      displayName: card.displayName,
      hardwareVersion: card.hardwareVersion,
      firmwareVersion: card.firmwareVersion,
      totalCapacity: card.totalCapacity,
      usedCapacity: card.usedCapacity,
      credentialIds: card.credentialIds.slice(),
      connectionState: card.connectionState,
      cardStatus: card.cardStatus,
      lastSeenAt: card.lastSeenAt,
      lastWrittenAt: card.lastWrittenAt,
      mockFailureMode: card.mockFailureMode
    }
  }

  private cloneCredentials(credentials: Credential[]): Credential[] {
    const result: Credential[] = []
    credentials.forEach((credential: Credential) => {
      result.push(this.cloneCredential(credential))
    })
    return result
  }

  private cloneCredential(credential: Credential): Credential {
    return {
      credentialId: credential.credentialId,
      permissionId: credential.permissionId,
      organizationId: credential.organizationId,
      physicalCardId: credential.physicalCardId,
      protocolVersion: credential.protocolVersion,
      credentialVersion: credential.credentialVersion,
      policyVersion: credential.policyVersion,
      permissionScopeDigest: credential.permissionScopeDigest,
      policyFlags: {
        recordEvent: credential.policyFlags.recordEvent,
        allowExecution: credential.policyFlags.allowExecution,
        adminConfirmRequired:
          credential.policyFlags.adminConfirmRequired,
        alertOnUnauthorized: credential.policyFlags.alertOnUnauthorized,
        alertLevel: credential.policyFlags.alertLevel,
        offlineAllowed: credential.policyFlags.offlineAllowed,
        phoneSubstituteAllowed:
          credential.policyFlags.phoneSubstituteAllowed,
        directionDetection: credential.policyFlags.directionDetection
      },
      validFrom: credential.validFrom,
      validUntil: credential.validUntil,
      keyVersion: credential.keyVersion,
      mockAuthenticationMaterial: credential.mockAuthenticationMaterial,
      integrityCheck: credential.integrityCheck,
      bindingStatus: credential.bindingStatus,
      condition: credential.condition,
      writtenAt: credential.writtenAt,
      verifiedAt: credential.verifiedAt
    }
  }

  private cloneCards(cards: DigitalCard[]): DigitalCard[] {
    const result: DigitalCard[] = []
    cards.forEach((card: DigitalCard) => {
      result.push(this.cloneCard(card))
    })
    return result
  }

  private cloneCard(card: DigitalCard): DigitalCard {
    return {
      id: card.id,
      name: card.name,
      issuer: card.issuer,
      cardAnonId: card.cardAnonId,
      anonymousNumber: card.anonymousNumber,
      nickname: card.nickname,
      detail: card.detail,
      category: card.category,
      status: card.status,
      visualStyle: card.visualStyle,
      permissionId: card.permissionId,
      credentialId: card.credentialId,
      physicalCardId: card.physicalCardId,
      credentialBindingStatus: card.credentialBindingStatus,
      credentialCondition: card.credentialCondition,
      adminConfirmRequired: card.adminConfirmRequired,
      userConfirmationEnabled: card.userConfirmationEnabled,
      allowTemporaryPass: card.allowTemporaryPass,
      validFrom: card.validFrom,
      validUntil: card.validUntil,
      syncState: {
        serverRevision: card.syncState.serverRevision,
        lastSyncAt: card.syncState.lastSyncAt,
        pendingOperations: card.syncState.pendingOperations.slice()
      }
    }
  }
}
