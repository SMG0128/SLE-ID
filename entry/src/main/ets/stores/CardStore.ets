import { DigitalCard, DigitalCardStatus } from '../models/DigitalCard'
import { Authorization } from '../models/Authorization'
import {
  Credential,
  CredentialBindingStatus
} from '../models/Credential'
import {
  PhysicalCard,
  PhysicalCardConnectionState,
  PhysicalCardDiscoveryState
} from '../models/PhysicalCard'
import {
  CredentialRemovalResult,
  CredentialWriteRequest,
  CredentialWriteResult,
  PhysicalCardConnectionResult,
  PhysicalCardDiscoveryUpdate,
  PhysicalCardFailureReason,
  PrimaryPhysicalCardBindingResult
} from '../models/PhysicalCardOperation'
import {
  InvitationFailureReason,
  InvitationFlowState,
  InvitationPreviewResult,
  InvitationRedemptionResult
} from '../models/Invitation'
import { DigitalCardService } from '../services/DigitalCardService'
import { AuthorizationService } from '../services/AuthorizationService'
import { InvitationService } from '../services/InvitationService'
import { PhysicalCardService } from '../services/PhysicalCardService'
import { CredentialService } from '../services/CredentialService'
import { MockDataSource } from '../mock/MockDataSource'
import {
  applyUserConfirmationPreference,
  ConfirmationPolicy,
  finalConfirmRequired
} from '../models/ConfirmationPolicy'
import {
  createPendingOperation,
  isAuthoritativeSuccess,
  OperationAuthority,
  OperationReceipt,
  OperationState
} from '../models/Operation'
import {
  CardMutationResult,
  CardPreferenceUpdate,
  MobileCardAction,
  PendingMobileMutation,
  PendingMobileMutationKind
} from '../models/MobileOperation'
import { PendingOperation, SyncState, createLocalSyncState } from '../models/SyncState'
import {
  PersistedCredentialState,
  WALLET_SCHEMA_VERSION,
  WalletPersistenceState
} from '../models/WalletPersistence'
import { WalletPersistenceService } from '../services/WalletPersistenceService'
import { MobileBackendService } from '../services/MobileBackendService'
import {
  CardProvisioningFailure,
  CardProvisioningResult,
  CardProvisioningStage
} from '../models/CardProvisioning'
import { CardProvisioningCoordinatorService } from '../services/CardProvisioningService'

export interface CardStoreConfiguration {
  cardService: DigitalCardService
  authorizationService: AuthorizationService
  invitationService: InvitationService
  physicalCardService: PhysicalCardService
  credentialService: CredentialService
  backendService: MobileBackendService | null
  persistenceService: WalletPersistenceService | null
  cachedState: WalletPersistenceState
  initialPhysicalCards: PhysicalCard[]
  initialCredentials: Credential[]
  provisioningService?: CardProvisioningCoordinatorService
}

@Observed
export class CardStore {
  private static instance: CardStore

  cards: DigitalCard[]
  authorizations: Authorization[]
  physicalCards: PhysicalCard[]
  primaryPhysicalCard: PhysicalCard | null
  discoveredPhysicalCards: PhysicalCard[] = []
  credentials: Credential[]
  discoveryState: PhysicalCardDiscoveryState = PhysicalCardDiscoveryState.IDLE
  connectionState: PhysicalCardConnectionState =
    PhysicalCardConnectionState.DISCONNECTED
  connectedPhysicalCardId: string = ''
  activeWriteStatus: CredentialBindingStatus =
    CredentialBindingStatus.NOT_WRITTEN
  physicalCardFailureReason: PhysicalCardFailureReason =
    PhysicalCardFailureReason.NONE
  provisioningStage: CardProvisioningStage = CardProvisioningStage.IDLE
  pendingWriteReceiptCount: number = 0
  isLoading: boolean = false
  errorMessage: string = ''
  isOffline: boolean = false
  syncState: SyncState = createLocalSyncState('')
  pendingMutations: PendingMobileMutation[] = []
  lastCardOperation: OperationReceipt = {
    operationId: '',
    state: OperationState.IDLE,
    authority: OperationAuthority.NONE,
    verificationRequired: false,
    receiptId: '',
    errorCode: '',
    updatedAt: ''
  }

  private cardService: DigitalCardService
  private authorizationService: AuthorizationService
  private invitationService: InvitationService
  private physicalCardService: PhysicalCardService
  private credentialService: CredentialService
  private backendService: MobileBackendService | null
  private persistenceService: WalletPersistenceService | null
  private isRecoveringPendingMutations: boolean = false
  private provisioningService: CardProvisioningCoordinatorService | null

  private constructor(
    cardService: DigitalCardService,
    authorizationService: AuthorizationService,
    invitationService: InvitationService,
    physicalCardService: PhysicalCardService,
    credentialService: CredentialService,
    initialCards: DigitalCard[],
    initialAuthorizations: Authorization[],
    initialPhysicalCards: PhysicalCard[],
    initialCredentials: Credential[],
    backendService: MobileBackendService | null,
    persistenceService: WalletPersistenceService | null,
    initialSyncState: SyncState,
    initialPendingMutations: PendingMobileMutation[],
    provisioningService: CardProvisioningCoordinatorService | null
  ) {
    this.cardService = cardService
    this.authorizationService = authorizationService
    this.invitationService = invitationService
    this.physicalCardService = physicalCardService
    this.credentialService = credentialService
    this.cards = initialCards
    this.authorizations = initialAuthorizations
    this.physicalCards = initialPhysicalCards
    this.primaryPhysicalCard =
      initialPhysicalCards.length > 0 ? initialPhysicalCards[0] : null
    this.credentials = initialCredentials
    this.backendService = backendService
    this.persistenceService = persistenceService
    this.syncState = initialSyncState
    this.pendingMutations = initialPendingMutations
    this.provisioningService = provisioningService
  }

  static configure(configuration: CardStoreConfiguration): void {
    CardStore.instance = new CardStore(
      configuration.cardService,
      configuration.authorizationService,
      configuration.invitationService,
      configuration.physicalCardService,
      configuration.credentialService,
      configuration.cachedState.cards,
      configuration.cachedState.authorizations,
      configuration.initialPhysicalCards,
      configuration.initialCredentials,
      configuration.backendService,
      configuration.persistenceService,
      configuration.cachedState.syncState,
      configuration.cachedState.pendingMutations,
      configuration.provisioningService ? configuration.provisioningService : null
    )
  }

  static getInstance(): CardStore {
    if (!CardStore.instance) {
      const mockDataSource: MockDataSource = MockDataSource.getInstance()
      CardStore.instance = new CardStore(
        mockDataSource,
        mockDataSource,
        mockDataSource,
        mockDataSource,
        mockDataSource,
        mockDataSource.getCardSnapshot(),
        mockDataSource.getAuthorizationSnapshot(),
        mockDataSource.getPhysicalCardSnapshot(),
        mockDataSource.getCredentialSnapshot(),
        null,
        null,
        createLocalSyncState(''),
        [],
        null
      )
    }
    return CardStore.instance
  }

  async refresh(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    try {
      const refreshedCards: DigitalCard[] = await this.cardService.listDigitalCards()
      const refreshedAuthorizations: Authorization[] =
        await this.authorizationService.listAllAuthorizations()
      const refreshedPrimaryPhysicalCard: PhysicalCard | null =
        await this.physicalCardService.getPrimaryPhysicalCard()
      const refreshedCredentials: Credential[] = []
      if (refreshedPrimaryPhysicalCard) {
        const cardCredentials: Credential[] =
          await this.credentialService.listCredentials(
            refreshedPrimaryPhysicalCard.physicalCardId
          )
        cardCredentials.forEach((credential: Credential) => {
          refreshedCredentials.push(credential)
        })
      }
      this.authorizations = refreshedAuthorizations
      this.cards = refreshedCards
      this.primaryPhysicalCard = refreshedPrimaryPhysicalCard
      this.physicalCards = refreshedPrimaryPhysicalCard ?
        [refreshedPrimaryPhysicalCard] : []
      this.credentials = refreshedCredentials
      if (this.backendService) {
        this.syncState = this.backendService.latestSyncState()
      } else {
        this.syncState.lastSyncAt = new Date().toISOString()
      }
      this.isOffline = false
      this.refreshPendingOperationContract()
      await this.persistWalletState()
      await this.recoverPendingMutations()
    } catch (error) {
      this.errorMessage = 'Unable to load cards'
      this.isOffline = true
    } finally {
      this.isLoading = false
    }
  }

  getCard(cardId: string): DigitalCard | null {
    let result: DigitalCard | null = null
    this.cards.forEach((card: DigitalCard) => {
      if (card.id === cardId) {
        result = card
      }
    })
    return result
  }

  isCardEnabled(card: DigitalCard): boolean {
    return card.status === DigitalCardStatus.ACTIVE
  }

  requiresConfirmation(card: DigitalCard): boolean {
    return finalConfirmRequired(
      card.adminConfirmRequired,
      card.userConfirmationEnabled
    )
  }

  hasAuthorization(authorizationId: string): boolean {
    let found: boolean = false
    this.authorizations.forEach((authorization: Authorization) => {
      if (authorization.permissionId === authorizationId) {
        found = true
      }
    })
    return found
  }

  getAuthorization(authorizationId: string): Authorization | null {
    let result: Authorization | null = null
    this.authorizations.forEach((authorization: Authorization) => {
      if (authorization.permissionId === authorizationId) {
        result = authorization
      }
    })
    return result
  }

  getPhysicalCard(physicalCardId: string): PhysicalCard | null {
    if (this.primaryPhysicalCard &&
      this.primaryPhysicalCard.physicalCardId === physicalCardId) {
      return this.primaryPhysicalCard
    }
    let result: PhysicalCard | null = null
    this.discoveredPhysicalCards.forEach((card: PhysicalCard) => {
      if (card.physicalCardId === physicalCardId) {
        result = card
      }
    })
    return result
  }

  getCredential(credentialId: string): Credential | null {
    let result: Credential | null = null
    this.credentials.forEach((credential: Credential) => {
      if (credential.credentialId === credentialId) {
        result = credential
      }
    })
    return result
  }

  getCredentialForCard(card: DigitalCard): Credential | null {
    if (card.credentialId.length === 0) {
      return null
    }
    return this.getCredential(card.credentialId)
  }

  startPhysicalCardDiscovery(): void {
    if (this.discoveryState === PhysicalCardDiscoveryState.DISCOVERING) {
      return
    }
    this.discoveryState = PhysicalCardDiscoveryState.DISCOVERING
    this.provisioningStage = CardProvisioningStage.SCANNING
    this.discoveredPhysicalCards = []
    this.physicalCardFailureReason = PhysicalCardFailureReason.NONE
    this.physicalCardService.startDiscovery((update: PhysicalCardDiscoveryUpdate) => {
      this.discoveryState = update.state
      if (update.state === PhysicalCardDiscoveryState.DISCOVERED) {
        this.discoveredPhysicalCards =
          this.deduplicatePhysicalCards(update.cards)
      } else if (update.state === PhysicalCardDiscoveryState.NO_DEVICE) {
        this.physicalCardFailureReason = PhysicalCardFailureReason.NO_DEVICE
      } else if (update.state === PhysicalCardDiscoveryState.DISCOVERY_FAILED) {
        this.physicalCardFailureReason =
          PhysicalCardFailureReason.DISCOVERY_FAILED
      }
    })
  }

  stopPhysicalCardDiscovery(): void {
    this.physicalCardService.stopDiscovery()
    this.discoveryState = PhysicalCardDiscoveryState.STOPPED
    if (this.provisioningStage === CardProvisioningStage.SCANNING) {
      this.provisioningStage = CardProvisioningStage.IDLE
    }
  }

  async connectPhysicalCard(
    physicalCardId: string
  ): Promise<PhysicalCardConnectionResult> {
    this.connectionState = PhysicalCardConnectionState.CONNECTING
    this.provisioningStage = CardProvisioningStage.CONNECTING
    this.connectedPhysicalCardId = physicalCardId
    this.physicalCardFailureReason = PhysicalCardFailureReason.NONE
    const result: PhysicalCardConnectionResult =
      await this.physicalCardService.connectPhysicalCard(physicalCardId)
    this.connectionState = result.state
    this.activeWriteStatus = CredentialBindingStatus.NOT_WRITTEN
    this.physicalCardFailureReason = result.reason
    if (result.card) {
      this.replacePhysicalCard(result.card)
    }
    if (result.state !== PhysicalCardConnectionState.CONNECTED) {
      this.connectedPhysicalCardId = ''
      this.provisioningStage = CardProvisioningStage.RETRYABLE_FAILURE
    } else {
      this.provisioningStage = CardProvisioningStage.IDLE
    }
    return result
  }

  async bindPrimaryPhysicalCard(
    physicalCardId: string
  ): Promise<PrimaryPhysicalCardBindingResult> {
    const result: PrimaryPhysicalCardBindingResult =
      await this.physicalCardService.bindPrimaryPhysicalCard(physicalCardId)
    this.physicalCardFailureReason = result.reason
    if (!result.success || !result.card) {
      return result
    }
    this.primaryPhysicalCard = result.card
    this.physicalCards = [result.card]
    this.cards = await this.cardService.listDigitalCards()
    this.credentials =
      await this.credentialService.listCredentials(physicalCardId)
    this.stopPhysicalCardDiscovery()
    return result
  }

  async disconnectPhysicalCard(): Promise<void> {
    if (this.connectedPhysicalCardId.length === 0) {
      return
    }
    const physicalCardId: string = this.connectedPhysicalCardId
    this.connectionState = PhysicalCardConnectionState.DISCONNECTING
    const result: PhysicalCardConnectionResult =
      await this.physicalCardService.disconnectPhysicalCard(physicalCardId)
    this.connectionState = result.state
    if (result.card) {
      this.replacePhysicalCard(result.card)
    }
    this.connectedPhysicalCardId = ''
  }

  async writeCardToPrimaryPhysicalCard(
    digitalCardId: string
  ): Promise<CredentialWriteResult> {
    const digitalCard: DigitalCard | null = this.getCard(digitalCardId)
    if (!digitalCard) {
      return this.physicalWriteErrorResult(
        PhysicalCardFailureReason.TRANSLATION_FAILED
      )
    }
    if (!this.primaryPhysicalCard) {
      return this.physicalWriteErrorResult(
        PhysicalCardFailureReason.NO_DEVICE
      )
    }
    if (this.activeWriteStatus === CredentialBindingStatus.WRITING ||
      this.activeWriteStatus === CredentialBindingStatus.VERIFYING) {
      return this.physicalWriteErrorResult(
        PhysicalCardFailureReason.WRITE_FAILED
      )
    }

    if (this.provisioningService) {
      return await this.writeUsingProvisioningCoordinator(
        digitalCard,
        this.primaryPhysicalCard
      )
    }

    const request: CredentialWriteRequest = {
      permissionId: digitalCard.permissionId,
      digitalCardId: digitalCard.id,
      physicalCardId: this.primaryPhysicalCard.physicalCardId
    }
    const previousBindingStatus: CredentialBindingStatus =
      digitalCard.credentialBindingStatus
    this.activeWriteStatus = CredentialBindingStatus.WRITING
    this.provisioningStage = CardProvisioningStage.WRITING
    this.physicalCardFailureReason = PhysicalCardFailureReason.NONE
    const result: CredentialWriteResult =
      await this.physicalCardService.writeCredential(
        request,
        (status: CredentialBindingStatus) => {
          this.activeWriteStatus = status
          this.provisioningStage = status === CredentialBindingStatus.VERIFYING ?
            CardProvisioningStage.VERIFYING : CardProvisioningStage.WRITING
          const activeCard: DigitalCard | null = this.getCard(digitalCardId)
          if (activeCard) {
            activeCard.credentialBindingStatus = status
            this.cards = this.cards.slice()
          }
        }
      )
    this.activeWriteStatus = result.status
    this.physicalCardFailureReason = result.reason
    this.provisioningStage = result.status === CredentialBindingStatus.ACTIVE ?
      CardProvisioningStage.SUCCESS : CardProvisioningStage.RETRYABLE_FAILURE
    if (result.physicalCard) {
      this.replacePhysicalCard(result.physicalCard)
    }
    if (result.digitalCard) {
      this.replaceDigitalCard(result.digitalCard)
    } else {
      const activeCard: DigitalCard | null = this.getCard(digitalCardId)
      if (activeCard) {
        activeCard.credentialBindingStatus = previousBindingStatus
        this.cards = this.cards.slice()
      }
    }
    if (result.credential &&
      result.credential.bindingStatus === CredentialBindingStatus.ACTIVE) {
      this.replaceCredential(result.credential)
    }
    return result
  }

  cancelCredentialWrite(): void {
    this.physicalCardService.cancelCredentialWrite()
    this.activeWriteStatus = CredentialBindingStatus.NOT_WRITTEN
    this.physicalCardFailureReason = PhysicalCardFailureReason.CANCELLED
    this.provisioningStage = CardProvisioningStage.RETRYABLE_FAILURE
  }

  async recoverPendingWriteReceipts(): Promise<number> {
    if (!this.provisioningService) {
      return 0
    }
    const acknowledged: number =
      await this.provisioningService.retryPendingReceipts()
    this.pendingWriteReceiptCount =
      this.provisioningService.pendingReceiptCount()
    if (acknowledged > 0) {
      await this.refresh()
    }
    return acknowledged
  }

  async removeCredentialFromPhysicalCard(
    credentialId: string
  ): Promise<CredentialRemovalResult> {
    const result: CredentialRemovalResult =
      await this.physicalCardService.removeCredential(credentialId)
    this.physicalCardFailureReason = result.reason
    if (!result.success) {
      return result
    }
    this.credentials = this.credentials.filter((credential: Credential) =>
      credential.credentialId !== credentialId)
    if (result.physicalCard) {
      this.replacePhysicalCard(result.physicalCard)
    }
    if (result.digitalCard) {
      this.replaceDigitalCard(result.digitalCard)
    }
    return result
  }

  validateInvitationFormat(code: string): boolean {
    return this.invitationService.validateInvitationFormat(code)
  }

  async previewInvitation(code: string): Promise<InvitationPreviewResult> {
    try {
      return await this.invitationService.previewInvitation(code)
    } catch (error) {
      return {
        state: InvitationFlowState.REQUEST_ERROR,
        reason: InvitationFailureReason.REQUEST_ERROR,
        preview: null
      }
    }
  }

  async redeemInvitation(code: string): Promise<InvitationRedemptionResult> {
    try {
      const result: InvitationRedemptionResult =
        await this.invitationService.redeemInvitation(code)
      if (result.state !== InvitationFlowState.SUCCESS) {
        return result
      }
      if (!result.authorization || !result.digitalCard) {
        return this.invitationRequestErrorResult()
      }
      if (this.hasAuthorization(result.authorization.permissionId)) {
        return {
          state: InvitationFlowState.ALREADY_BOUND,
          reason: InvitationFailureReason.ALREADY_BOUND,
          operation: {
            operationId: result.operation.operationId,
            state: OperationState.FAILED,
            authority: OperationAuthority.LOCAL,
            verificationRequired: false,
            receiptId: '',
            errorCode: InvitationFailureReason.ALREADY_BOUND,
            updatedAt: new Date().toISOString()
          },
          preview: result.preview,
          authorization: null,
          digitalCard: null
        }
      }

      const updatedAuthorizations: Authorization[] = this.authorizations.slice()
      const updatedCards: DigitalCard[] = this.cards.slice()
      updatedAuthorizations.push(result.authorization)
      updatedCards.push(result.digitalCard)
      this.authorizations = updatedAuthorizations
      this.cards = updatedCards
      await this.persistWalletState()
      return result
    } catch (error) {
      return this.invitationRequestErrorResult()
    }
  }

  async isInvitationUsed(code: string): Promise<boolean> {
    return await this.invitationService.isInvitationUsed(code)
  }

  async isAuthorizationBound(authorizationId: string): Promise<boolean> {
    return await this.invitationService.isAuthorizationBound(authorizationId)
  }

  async updateNickname(cardId: string, value: string): Promise<boolean> {
    return await this.updatePreferences(cardId, { nickname: value })
  }

  async updateCategory(cardId: string, value: string): Promise<boolean> {
    return await this.updatePreferences(cardId, { category: value })
  }

  async updateEnabled(cardId: string, isEnabled: boolean): Promise<boolean> {
    if (this.backendService) {
      return await this.runBackendAction(
        cardId,
        isEnabled ? MobileCardAction.RESTORE : MobileCardAction.FREEZE
      )
    }
    const card: DigitalCard | null = this.getCard(cardId)
    if (!card) {
      return false
    }
    const updatedCard: DigitalCard = this.cloneDigitalCard(card)
    updatedCard.status = isEnabled ? DigitalCardStatus.ACTIVE : DigitalCardStatus.FROZEN
    return await this.saveLocallyAcknowledgedCard(updatedCard)
  }

  async markCardLost(cardId: string): Promise<boolean> {
    return await this.runBackendAction(cardId, MobileCardAction.LOST)
  }

  async updateUserConfirmation(
    cardId: string,
    isEnabled: boolean
  ): Promise<boolean> {
    const card: DigitalCard | null = this.getCard(cardId)
    if (!card) {
      return false
    }
    const currentPolicy: ConfirmationPolicy = {
      adminConfirmRequired: card.adminConfirmRequired,
      userConfirmEnabled: card.userConfirmationEnabled
    }
    const nextPolicy: ConfirmationPolicy =
      applyUserConfirmationPreference(currentPolicy, isEnabled)
    return await this.updatePreferences(cardId, {
      userConfirmEnabled: nextPolicy.userConfirmEnabled
    })
  }

  async removeCard(cardId: string): Promise<void> {
    if (this.backendService) {
      const success: boolean = await this.runBackendAction(
        cardId,
        MobileCardAction.UNBIND
      )
      if (!success) {
        throw new Error('Backend did not acknowledge card unbind')
      }
      this.cards = this.cards.filter((card: DigitalCard) => card.id !== cardId)
      await this.persistWalletState()
      return
    }
    await this.cardService.removeDigitalCard(cardId)
    this.cards = this.cards.filter((card: DigitalCard) => card.id !== cardId)
  }

  private async updatePreferences(
    cardId: string,
    update: CardPreferenceUpdate
  ): Promise<boolean> {
    const card: DigitalCard | null = this.getCard(cardId)
    if (!card) {
      return false
    }
    if (this.backendService) {
      const mutation: PendingMobileMutation = this.createMutation(
        PendingMobileMutationKind.PREFERENCES,
        cardId,
        update,
        null
      )
      return await this.executeBackendMutation(mutation)
    }
    const updatedCard: DigitalCard = this.cloneDigitalCard(card)
    if (update.nickname !== undefined) {
      updatedCard.nickname = update.nickname
    }
    if (update.category !== undefined) {
      updatedCard.category = update.category
    }
    if (update.userConfirmEnabled !== undefined) {
      updatedCard.userConfirmationEnabled = update.userConfirmEnabled
    }
    return await this.saveLocallyAcknowledgedCard(updatedCard)
  }

  private async runBackendAction(
    cardId: string,
    action: MobileCardAction
  ): Promise<boolean> {
    if (!this.backendService) {
      return false
    }
    const mutation: PendingMobileMutation = this.createMutation(
      PendingMobileMutationKind.ACTION,
      cardId,
      null,
      action
    )
    return await this.executeBackendMutation(mutation)
  }

  private createMutation(
    kind: PendingMobileMutationKind,
    cardId: string,
    update: CardPreferenceUpdate | null,
    action: MobileCardAction | null
  ): PendingMobileMutation {
    const timestamp: string = new Date().toISOString()
    return {
      operationId: `mobile-${kind}-${cardId}-${Date.now()}`,
      kind: kind,
      cardId: cardId,
      preferenceUpdate: update,
      action: action,
      createdAt: timestamp,
      lastAttemptAt: '',
      attemptCount: 0,
      state: OperationState.PENDING
    }
  }

  private async executeBackendMutation(
    mutation: PendingMobileMutation
  ): Promise<boolean> {
    this.pendingMutations.push(mutation)
    this.refreshPendingOperationContract()
    this.lastCardOperation = createPendingOperation(
      mutation.operationId,
      OperationAuthority.BACKEND,
      false,
      mutation.createdAt
    )
    await this.persistWalletState()
    try {
      const result: CardMutationResult = await this.sendMutation(mutation)
      if (!isAuthoritativeSuccess(result.operation)) {
        throw new Error('Missing backend acknowledgement')
      }
      if (result.card) {
        this.replaceDigitalCard(result.card)
      }
      this.lastCardOperation = result.operation
      this.removePendingMutation(mutation.operationId)
      this.isOffline = false
      this.errorMessage = ''
      await this.persistWalletState()
      return true
    } catch (error) {
      if (!this.hasPendingMutation(mutation.operationId)) {
        this.pendingMutations.push(mutation)
      }
      mutation.state = OperationState.FAILED
      mutation.lastAttemptAt = new Date().toISOString()
      mutation.attemptCount++
      this.lastCardOperation = {
        operationId: mutation.operationId,
        state: OperationState.FAILED,
        authority: OperationAuthority.BACKEND,
        verificationRequired: false,
        receiptId: '',
        errorCode: 'BACKEND_REQUEST_FAILED',
        updatedAt: mutation.lastAttemptAt
      }
      this.errorMessage = 'Unable to synchronize card change'
      this.isOffline = true
      this.refreshPendingOperationContract()
      await this.persistWalletState()
      return false
    }
  }

  private async sendMutation(
    mutation: PendingMobileMutation
  ): Promise<CardMutationResult> {
    if (!this.backendService) {
      throw new Error('Backend service unavailable')
    }
    if (mutation.kind === PendingMobileMutationKind.PREFERENCES &&
      mutation.preferenceUpdate) {
      return await this.backendService.updateCardPreferences(
        mutation.cardId,
        mutation.preferenceUpdate
      )
    }
    if (mutation.kind === PendingMobileMutationKind.ACTION && mutation.action) {
      return await this.backendService.performCardAction(
        mutation.cardId,
        mutation.action
      )
    }
    throw new Error('Invalid pending mutation')
  }

  private async saveLocallyAcknowledgedCard(card: DigitalCard): Promise<boolean> {
    const operationId: string = `card-save-${card.id}-${Date.now()}`
    this.lastCardOperation = createPendingOperation(
      operationId,
      OperationAuthority.LOCAL,
      false,
      new Date().toISOString()
    )
    try {
      const savedCard: DigitalCard = await this.cardService.saveDigitalCard(card)
      this.replaceDigitalCard(savedCard)
      this.lastCardOperation = {
        operationId: operationId,
        state: OperationState.ACKNOWLEDGED,
        authority: OperationAuthority.LOCAL,
        verificationRequired: false,
        receiptId: `local-${operationId}`,
        errorCode: '',
        updatedAt: new Date().toISOString()
      }
      return true
    } catch (error) {
      this.errorMessage = 'Unable to save card'
      this.lastCardOperation = {
        operationId: operationId,
        state: OperationState.FAILED,
        authority: OperationAuthority.LOCAL,
        verificationRequired: false,
        receiptId: '',
        errorCode: 'PERSISTENCE_FAILED',
        updatedAt: new Date().toISOString()
      }
      return false
    }
  }

  private async recoverPendingMutations(): Promise<void> {
    if (!this.backendService || this.isRecoveringPendingMutations ||
      this.pendingMutations.length === 0) {
      return
    }
    this.isRecoveringPendingMutations = true
    const recoverable: PendingMobileMutation[] = this.pendingMutations.slice()
    for (let index: number = 0; index < recoverable.length; index++) {
      const mutation: PendingMobileMutation = recoverable[index]
      mutation.state = OperationState.PENDING
      mutation.lastAttemptAt = new Date().toISOString()
      mutation.attemptCount++
      try {
        const result: CardMutationResult = await this.sendMutation(mutation)
        if (!isAuthoritativeSuccess(result.operation)) {
          throw new Error('Missing backend acknowledgement')
        }
        if (result.card) {
          this.replaceDigitalCard(result.card)
        }
        this.lastCardOperation = result.operation
        this.removePendingMutation(mutation.operationId)
      } catch (error) {
        mutation.state = OperationState.FAILED
        this.isOffline = true
        this.errorMessage = 'Some card changes are pending synchronization'
      }
    }
    this.refreshPendingOperationContract()
    try {
      await this.persistWalletState()
    } finally {
      this.isRecoveringPendingMutations = false
    }
  }

  private hasPendingMutation(operationId: string): boolean {
    let found: boolean = false
    this.pendingMutations.forEach((mutation: PendingMobileMutation) => {
      if (mutation.operationId === operationId) {
        found = true
      }
    })
    return found
  }

  private removePendingMutation(operationId: string): void {
    this.pendingMutations = this.pendingMutations.filter(
      (mutation: PendingMobileMutation) => mutation.operationId !== operationId
    )
    this.refreshPendingOperationContract()
  }

  private refreshPendingOperationContract(): void {
    const pendingOperations: PendingOperation[] = []
    this.pendingMutations.forEach((mutation: PendingMobileMutation) => {
      pendingOperations.push({
        operationId: mutation.operationId,
        operationType: mutation.kind,
        state: mutation.state,
        authority: OperationAuthority.BACKEND,
        createdAt: mutation.createdAt,
        lastAttemptAt: mutation.lastAttemptAt,
        attemptCount: mutation.attemptCount,
        payloadReference: `${mutation.kind}:${mutation.cardId}`
      })
    })
    this.syncState.pendingOperations = pendingOperations
  }

  private async persistWalletState(): Promise<void> {
    if (!this.persistenceService) {
      return
    }
    const credentialStates: PersistedCredentialState[] = []
    this.credentials.forEach((credential: Credential) => {
      credentialStates.push({
        credentialId: credential.credentialId,
        permissionId: credential.permissionId,
        physicalCardId: credential.physicalCardId,
        bindingStatus: credential.bindingStatus,
        condition: credential.condition,
        writtenAt: credential.writtenAt,
        verifiedAt: credential.verifiedAt
      })
    })
    const state: WalletPersistenceState = {
      schemaVersion: WALLET_SCHEMA_VERSION,
      cards: this.cards,
      authorizations: this.authorizations,
      credentialStates: credentialStates,
      syncState: this.syncState,
      pendingMutations: this.pendingMutations
    }
    await this.persistenceService.save(state)
  }

  private invitationRequestErrorResult(): InvitationRedemptionResult {
    const timestamp: string = new Date().toISOString()
    return {
      state: InvitationFlowState.REQUEST_ERROR,
      reason: InvitationFailureReason.REQUEST_ERROR,
      operation: {
        operationId: `invite-redeem-${timestamp}`,
        state: OperationState.FAILED,
        authority: OperationAuthority.LOCAL,
        verificationRequired: false,
        receiptId: '',
        errorCode: InvitationFailureReason.REQUEST_ERROR,
        updatedAt: timestamp
      },
      preview: null,
      authorization: null,
      digitalCard: null
    }
  }

  private async writeUsingProvisioningCoordinator(
    digitalCard: DigitalCard,
    physicalCard: PhysicalCard
  ): Promise<CredentialWriteResult> {
    if (!this.provisioningService) {
      return this.physicalWriteErrorResult(
        PhysicalCardFailureReason.WRITE_FAILED
      )
    }
    this.physicalCardFailureReason = PhysicalCardFailureReason.NONE
    const result: CardProvisioningResult =
      await this.provisioningService.provision(
        digitalCard.id,
        physicalCard.physicalCardId,
        (stage: CardProvisioningStage) => {
          this.provisioningStage = stage
          if (stage === CardProvisioningStage.WRITING ||
            stage === CardProvisioningStage.AUTHENTICATING) {
            this.activeWriteStatus = CredentialBindingStatus.WRITING
          } else if (stage === CardProvisioningStage.VERIFYING ||
            stage === CardProvisioningStage.SYNCHRONIZING) {
            this.activeWriteStatus = CredentialBindingStatus.VERIFYING
          }
        }
      )
    this.provisioningStage = result.stage
    this.pendingWriteReceiptCount =
      this.provisioningService.pendingReceiptCount()
    this.physicalCardFailureReason =
      this.mapProvisioningFailure(result.failure)

    if (result.physicalVerified && result.backendAcknowledged &&
      result.stage === CardProvisioningStage.SUCCESS) {
      digitalCard.credentialBindingStatus = CredentialBindingStatus.ACTIVE
      digitalCard.physicalCardId = physicalCard.physicalCardId
      this.activeWriteStatus = CredentialBindingStatus.ACTIVE
      this.cards = this.cards.slice()
      await this.persistWalletState()
      return {
        status: CredentialBindingStatus.ACTIVE,
        reason: PhysicalCardFailureReason.NONE,
        operation: result.physicalOperation,
        credential: null,
        physicalCard: physicalCard,
        digitalCard: digitalCard
      }
    }

    if (result.physicalVerified && result.receiptPending) {
      // Physical readback is known, but the UI remains in Synchronizing until
      // the backend receipt is acknowledged. Recovery never repeats SLE write.
      digitalCard.credentialBindingStatus = CredentialBindingStatus.VERIFYING
      this.activeWriteStatus = CredentialBindingStatus.VERIFYING
      this.cards = this.cards.slice()
      await this.persistWalletState()
      return {
        status: CredentialBindingStatus.VERIFYING,
        reason: PhysicalCardFailureReason.PERSISTENCE_FAILED,
        operation: result.receiptOperation,
        credential: null,
        physicalCard: physicalCard,
        digitalCard: digitalCard
      }
    }

    digitalCard.credentialBindingStatus = CredentialBindingStatus.WRITE_FAILED
    this.activeWriteStatus = CredentialBindingStatus.WRITE_FAILED
    this.cards = this.cards.slice()
    await this.persistWalletState()
    return {
      status: CredentialBindingStatus.WRITE_FAILED,
      reason: this.physicalCardFailureReason,
      operation: result.physicalOperation,
      credential: null,
      physicalCard: physicalCard,
      digitalCard: digitalCard
    }
  }

  private mapProvisioningFailure(
    failure: CardProvisioningFailure
  ): PhysicalCardFailureReason {
    if (failure === CardProvisioningFailure.NONE) {
      return PhysicalCardFailureReason.NONE
    }
    if (failure === CardProvisioningFailure.SCAN_TIMEOUT) {
      return PhysicalCardFailureReason.NO_DEVICE
    }
    if (failure === CardProvisioningFailure.CONNECTION_FAILED) {
      return PhysicalCardFailureReason.CONNECTION_FAILED
    }
    if (failure === CardProvisioningFailure.CONNECTION_INTERRUPTED) {
      return PhysicalCardFailureReason.CONNECTION_INTERRUPTED
    }
    if (failure === CardProvisioningFailure.READBACK_MISMATCH ||
      failure === CardProvisioningFailure.IDENTITY_MISMATCH) {
      return PhysicalCardFailureReason.VERIFICATION_FAILED
    }
    if (failure === CardProvisioningFailure.RECEIPT_UPLOAD_FAILED ||
      failure === CardProvisioningFailure.RECEIPT_PERSISTENCE_FAILED) {
      return PhysicalCardFailureReason.PERSISTENCE_FAILED
    }
    return PhysicalCardFailureReason.WRITE_FAILED
  }

  private physicalWriteErrorResult(
    reason: PhysicalCardFailureReason
  ): CredentialWriteResult {
    const timestamp: string = new Date().toISOString()
    return {
      status: CredentialBindingStatus.WRITE_FAILED,
      reason: reason,
      operation: {
        operationId: `credential-write-${timestamp}`,
        state: OperationState.FAILED,
        authority: OperationAuthority.PHYSICAL_CARD,
        verificationRequired: true,
        receiptId: '',
        errorCode: reason,
        updatedAt: timestamp
      },
      credential: null,
      physicalCard: null,
      digitalCard: null
    }
  }

  private replacePhysicalCard(card: PhysicalCard): void {
    if (this.primaryPhysicalCard &&
      this.primaryPhysicalCard.physicalCardId === card.physicalCardId) {
      this.primaryPhysicalCard = card
      this.physicalCards = [card]
    }
    const updatedDiscoveredCards: PhysicalCard[] = []
    this.discoveredPhysicalCards.forEach((item: PhysicalCard) => {
      updatedDiscoveredCards.push(
        item.physicalCardId === card.physicalCardId ? card : item
      )
    })
    this.discoveredPhysicalCards = updatedDiscoveredCards
  }

  private replaceDigitalCard(card: DigitalCard): void {
    this.cards = this.cards.map((item: DigitalCard) =>
      item.id === card.id ? card : item)
  }

  private cloneDigitalCard(card: DigitalCard): DigitalCard {
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
      syncState: card.syncState
    }
  }

  private replaceCredential(credential: Credential): void {
    const updatedCredentials: Credential[] = []
    let replaced: boolean = false
    this.credentials.forEach((item: Credential) => {
      if (item.credentialId === credential.credentialId) {
        updatedCredentials.push(credential)
        replaced = true
      } else {
        updatedCredentials.push(item)
      }
    })
    if (!replaced) {
      updatedCredentials.push(credential)
    }
    this.credentials = updatedCredentials
  }

  private deduplicatePhysicalCards(cards: PhysicalCard[]): PhysicalCard[] {
    const result: PhysicalCard[] = []
    cards.forEach((card: PhysicalCard) => {
      let exists: boolean = false
      result.forEach((item: PhysicalCard) => {
        if (item.physicalCardId === card.physicalCardId) {
          exists = true
        }
      })
      if (!exists) {
        result.push(card)
      }
    })
    return result
  }
}
