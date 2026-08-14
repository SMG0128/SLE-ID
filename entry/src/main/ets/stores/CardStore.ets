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
  isLoading: boolean = false
  errorMessage: string = ''

  private cardService: DigitalCardService
  private authorizationService: AuthorizationService
  private invitationService: InvitationService
  private physicalCardService: PhysicalCardService
  private credentialService: CredentialService

  private constructor(
    cardService: DigitalCardService,
    authorizationService: AuthorizationService,
    invitationService: InvitationService,
    physicalCardService: PhysicalCardService,
    credentialService: CredentialService,
    initialCards: DigitalCard[],
    initialAuthorizations: Authorization[],
    initialPhysicalCards: PhysicalCard[],
    initialCredentials: Credential[]
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
        mockDataSource.getCredentialSnapshot()
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
    } catch (error) {
      this.errorMessage = 'Unable to load cards'
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
    return card.adminConfirmationRequired || card.userConfirmationEnabled
  }

  hasAuthorization(authorizationId: string): boolean {
    let found: boolean = false
    this.authorizations.forEach((authorization: Authorization) => {
      if (authorization.id === authorizationId) {
        found = true
      }
    })
    return found
  }

  getAuthorization(authorizationId: string): Authorization | null {
    let result: Authorization | null = null
    this.authorizations.forEach((authorization: Authorization) => {
      if (authorization.id === authorizationId) {
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
    this.activeWriteStatus = CredentialBindingStatus.DISCOVERING
    this.discoveredPhysicalCards = []
    this.physicalCardFailureReason = PhysicalCardFailureReason.NONE
    this.physicalCardService.startDiscovery((update: PhysicalCardDiscoveryUpdate) => {
      this.discoveryState = update.state
      if (update.state !== PhysicalCardDiscoveryState.DISCOVERING &&
        this.activeWriteStatus === CredentialBindingStatus.DISCOVERING) {
        this.activeWriteStatus = CredentialBindingStatus.NOT_WRITTEN
      }
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
    if (this.activeWriteStatus === CredentialBindingStatus.DISCOVERING) {
      this.activeWriteStatus = CredentialBindingStatus.NOT_WRITTEN
    }
  }

  async connectPhysicalCard(
    physicalCardId: string
  ): Promise<PhysicalCardConnectionResult> {
    this.connectionState = PhysicalCardConnectionState.CONNECTING
    this.activeWriteStatus = CredentialBindingStatus.CONNECTING
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

    const request: CredentialWriteRequest = {
      authorizationId: digitalCard.authorizationId,
      digitalCardId: digitalCard.id,
      physicalCardId: this.primaryPhysicalCard.physicalCardId
    }
    const previousBindingStatus: CredentialBindingStatus =
      digitalCard.credentialBindingStatus
    this.activeWriteStatus = CredentialBindingStatus.WRITING
    this.physicalCardFailureReason = PhysicalCardFailureReason.NONE
    const result: CredentialWriteResult =
      await this.physicalCardService.writeCredential(
        request,
        (status: CredentialBindingStatus) => {
          this.activeWriteStatus = status
          const activeCard: DigitalCard | null = this.getCard(digitalCardId)
          if (activeCard) {
            activeCard.credentialBindingStatus = status
            this.cards = this.cards.slice()
          }
        }
      )
    this.activeWriteStatus = result.status
    this.physicalCardFailureReason = result.reason
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
      result.credential.bindingStatus === CredentialBindingStatus.WRITTEN) {
      this.replaceCredential(result.credential)
    }
    return result
  }

  cancelCredentialWrite(): void {
    this.physicalCardService.cancelCredentialWrite()
    this.activeWriteStatus = CredentialBindingStatus.NOT_WRITTEN
    this.physicalCardFailureReason = PhysicalCardFailureReason.CANCELLED
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
      if (this.hasAuthorization(result.authorization.id)) {
        return {
          state: InvitationFlowState.ALREADY_BOUND,
          reason: InvitationFailureReason.ALREADY_BOUND,
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

  updateNickname(cardId: string, value: string): void {
    const card: DigitalCard | null = this.getCard(cardId)
    if (!card) {
      return
    }
    card.nickname = value
    this.publishAndPersist(card)
  }

  updateCategory(cardId: string, value: string): void {
    const card: DigitalCard | null = this.getCard(cardId)
    if (!card) {
      return
    }
    card.category = value
    this.publishAndPersist(card)
  }

  updateEnabled(cardId: string, isEnabled: boolean): void {
    const card: DigitalCard | null = this.getCard(cardId)
    if (!card) {
      return
    }
    card.status = isEnabled ? DigitalCardStatus.ACTIVE : DigitalCardStatus.FROZEN
    this.publishAndPersist(card)
  }

  updateUserConfirmation(cardId: string, isEnabled: boolean): void {
    const card: DigitalCard | null = this.getCard(cardId)
    if (!card) {
      return
    }
    if (card.adminConfirmationRequired && !isEnabled) {
      return
    }
    card.userConfirmationEnabled = isEnabled
    this.publishAndPersist(card)
  }

  async removeCard(cardId: string): Promise<void> {
    await this.cardService.removeDigitalCard(cardId)
    this.cards = this.cards.filter((card: DigitalCard) => card.id !== cardId)
  }

  private publishAndPersist(card: DigitalCard): void {
    this.cards = this.cards.slice()
    this.cardService.saveDigitalCard(card).catch(() => {
      this.errorMessage = 'Unable to save card'
    })
  }

  private invitationRequestErrorResult(): InvitationRedemptionResult {
    return {
      state: InvitationFlowState.REQUEST_ERROR,
      reason: InvitationFailureReason.REQUEST_ERROR,
      preview: null,
      authorization: null,
      digitalCard: null
    }
  }

  private physicalWriteErrorResult(
    reason: PhysicalCardFailureReason
  ): CredentialWriteResult {
    return {
      status: CredentialBindingStatus.WRITE_FAILED,
      reason: reason,
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
