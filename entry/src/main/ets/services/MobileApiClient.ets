import { Authorization } from '../models/Authorization'
import { ConfirmationRequest } from '../models/ConfirmationRequest'
import { ConfirmationDecisionResult } from '../models/ConfirmationOperation'
import { ConfirmationRequestStatus } from '../models/ConfirmationRequest'
import { CredentialBindingStatus } from '../models/Credential'
import { DigitalCard } from '../models/DigitalCard'
import {
  InvitationFailureReason,
  InvitationFlowState,
  InvitationPreviewResult,
  InvitationRedemptionResult
} from '../models/Invitation'
import { MobilePairRequest, MobileSession } from '../models/MobileSession'
import {
  CardMutationResult,
  CardPreferenceUpdate,
  MobileCardAction
} from '../models/MobileOperation'
import {
  isAuthoritativeSuccess,
  OperationAuthority
} from '../models/Operation'
import { createLocalSyncState, SyncState } from '../models/SyncState'
import { SessionStore } from '../stores/SessionStore'
import { AuthorizationService } from './AuthorizationService'
import { DigitalCardService } from './DigitalCardService'
import { InvitationService } from './InvitationService'
import {
  CardMutationResponse,
  ConfirmationDecisionResponse,
  InvitationPreviewResponse,
  InvitationRedeemResponse,
  MobileHttpRequest,
  MobileHttpResponse,
  MobileHttpTransport,
  PairResponse,
  PendingConfirmationsResponse,
  WalletResponse
} from './MobileApiContracts'
import { MobileBackendService } from './MobileBackendService'
import { ConfirmationBackendService } from './ConfirmationBackendService'

export class MobileApiError extends Error {
  readonly statusCode: number

  constructor(statusCode: number, message: string) {
    super(message)
    this.statusCode = statusCode
  }
}

export function createCardPreferenceBody(update: CardPreferenceUpdate): string {
  return JSON.stringify(update)
}

export function preserveAdminConfirmationRequirement(
  current: DigitalCard,
  mapped: DigitalCard
): DigitalCard {
  if (!current.adminConfirmRequired || mapped.adminConfirmRequired) {
    return mapped
  }
  return {
    id: mapped.id,
    name: mapped.name,
    issuer: mapped.issuer,
    cardAnonId: mapped.cardAnonId,
    anonymousNumber: mapped.anonymousNumber,
    nickname: mapped.nickname,
    detail: mapped.detail,
    category: mapped.category,
    status: mapped.status,
    visualStyle: mapped.visualStyle,
    permissionId: mapped.permissionId,
    credentialId: mapped.credentialId,
    physicalCardId: mapped.physicalCardId,
    credentialBindingStatus: mapped.credentialBindingStatus,
    credentialCondition: mapped.credentialCondition,
    adminConfirmRequired: true,
    userConfirmationEnabled: mapped.userConfirmationEnabled,
    allowTemporaryPass: mapped.allowTemporaryPass,
    validFrom: mapped.validFrom,
    validUntil: mapped.validUntil,
    syncState: mapped.syncState
  }
}

export class MobileApiClient implements
  DigitalCardService,
  AuthorizationService,
  InvitationService,
  MobileBackendService,
  ConfirmationBackendService {
  private readonly transport: MobileHttpTransport
  private readonly sessionStore: SessionStore
  private cachedCards: DigitalCard[] = []
  private cachedAuthorizations: Authorization[] = []
  private syncState: SyncState = createLocalSyncState('')

  constructor(transport: MobileHttpTransport, sessionStore: SessionStore) {
    this.transport = transport
    this.sessionStore = sessionStore
  }

  async pair(request: MobilePairRequest): Promise<MobileSession> {
    const response: PairResponse = await this.send<PairResponse>(
      'POST',
      '/api/mobile/pair',
      JSON.stringify(request),
      false
    )
    await this.sessionStore.accept(response.session)
    return response.session
  }

  async listDigitalCards(): Promise<DigitalCard[]> {
    const response: WalletResponse = await this.send<WalletResponse>(
      'GET',
      '/api/mobile/cards',
      '',
      true
    )
    if (!Array.isArray(response.cards) ||
      !Array.isArray(response.authorizations)) {
      throw new MobileApiError(0, 'Invalid wallet response')
    }
    this.cachedCards = response.cards
    this.cachedAuthorizations = response.authorizations
    this.syncState = {
      serverRevision: response.serverRevision || '',
      lastSyncAt: new Date().toISOString(),
      pendingOperations: this.syncState.pendingOperations
    }
    return this.cachedCards.slice()
  }

  async getDigitalCard(cardId: string): Promise<DigitalCard | null> {
    let result: DigitalCard | null = null
    this.cachedCards.forEach((card: DigitalCard) => {
      if (card.id === cardId) {
        result = card
      }
    })
    return result
  }

  async saveDigitalCard(card: DigitalCard): Promise<DigitalCard> {
    const result: CardMutationResult = await this.updateCardPreferences(
      card.id,
      {
        nickname: card.nickname,
        category: card.category,
        userConfirmEnabled: card.userConfirmationEnabled
      }
    )
    if (!result.card) {
      throw new MobileApiError(0, 'Backend acknowledgement omitted card')
    }
    return result.card
  }

  async removeDigitalCard(cardId: string): Promise<void> {
    await this.performCardAction(cardId, MobileCardAction.UNBIND)
  }

  async listAllAuthorizations(): Promise<Authorization[]> {
    return this.cachedAuthorizations.slice()
  }

  async listAuthorizations(digitalCardId: string): Promise<Authorization[]> {
    return this.cachedAuthorizations.filter((authorization: Authorization) =>
      authorization.digitalCardId === digitalCardId)
  }

  async getAuthorization(authorizationId: string): Promise<Authorization | null> {
    let result: Authorization | null = null
    this.cachedAuthorizations.forEach((authorization: Authorization) => {
      if (authorization.permissionId === authorizationId) {
        result = authorization
      }
    })
    return result
  }

  validateInvitationFormat(code: string): boolean {
    const normalizedCode: string = code.trim().toUpperCase()
    if (normalizedCode.length !== 13 ||
      normalizedCode.substring(0, 4) !== 'SLE-' ||
      normalizedCode.charAt(8) !== '-') {
      return false
    }
    for (let index: number = 4; index < normalizedCode.length; index++) {
      if (index === 8) {
        continue
      }
      const character: string = normalizedCode.charAt(index)
      const isLetter: boolean = character >= 'A' && character <= 'Z'
      const isNumber: boolean = character >= '0' && character <= '9'
      if (!isLetter && !isNumber) {
        return false
      }
    }
    return true
  }

  async previewInvitation(code: string): Promise<InvitationPreviewResult> {
    const response: InvitationPreviewResponse =
      await this.send<InvitationPreviewResponse>(
        'POST',
        '/api/mobile/invites/preview',
        JSON.stringify({ code: code }),
        true
      )
    return {
      state: InvitationFlowState.PREVIEW_READY,
      reason: InvitationFailureReason.NONE,
      preview: response.preview
    }
  }

  async redeemInvitation(code: string): Promise<InvitationRedemptionResult> {
    const response: InvitationRedeemResponse =
      await this.send<InvitationRedeemResponse>(
        'POST',
        '/api/mobile/invites/redeem',
        JSON.stringify({ code: code }),
        true
      )
    if (response.result.state === InvitationFlowState.SUCCESS &&
      (!isAuthoritativeSuccess(response.result.operation) ||
        response.result.operation.authority !== OperationAuthority.BACKEND)) {
      throw new MobileApiError(0, 'Invite redemption lacks backend receipt')
    }
    if (response.result.state === InvitationFlowState.SUCCESS &&
      response.result.digitalCard) {
      response.result.digitalCard.credentialBindingStatus =
        CredentialBindingStatus.NOT_WRITTEN
    }
    return response.result
  }

  async isInvitationUsed(code: string): Promise<boolean> {
    throw new MobileApiError(0, 'Invitation usage lookup is not in the mobile API contract')
  }

  async isAuthorizationBound(authorizationId: string): Promise<boolean> {
    return (await this.getAuthorization(authorizationId)) !== null
  }

  async updateCardPreferences(
    cardId: string,
    update: CardPreferenceUpdate
  ): Promise<CardMutationResult> {
    const response: CardMutationResponse =
      await this.send<CardMutationResponse>(
        'PATCH',
        `/api/mobile/cards/${encodeURIComponent(cardId)}/preferences`,
        createCardPreferenceBody(update),
        true
      )
    this.requireBackendAcknowledgement(response.result)
    if (!response.result.card) {
      throw new MobileApiError(0, 'Preference acknowledgement omitted card')
    }
    response.result.card = this.preserveCachedAdminPolicy(response.result.card)
    this.cacheCard(response.result.card)
    return response.result
  }

  async performCardAction(
    cardId: string,
    action: MobileCardAction
  ): Promise<CardMutationResult> {
    const response: CardMutationResponse =
      await this.send<CardMutationResponse>(
        'POST',
        `/api/mobile/cards/${encodeURIComponent(cardId)}/actions`,
        JSON.stringify({ action: action }),
        true
      )
    this.requireBackendAcknowledgement(response.result)
    if (response.result.card) {
      response.result.card = this.preserveCachedAdminPolicy(response.result.card)
      this.cacheCard(response.result.card)
    } else if (action !== MobileCardAction.UNBIND) {
      throw new MobileApiError(0, 'Security action acknowledgement omitted card')
    }
    return response.result
  }

  async listPendingConfirmations(): Promise<ConfirmationRequest[]> {
    const response: PendingConfirmationsResponse =
      await this.send<PendingConfirmationsResponse>(
        'GET',
        '/api/mobile/confirmations/pending',
        '',
        true
      )
    return response.confirmations
  }

  async decideConfirmation(
    requestId: string,
    status: ConfirmationRequestStatus
  ): Promise<ConfirmationDecisionResult> {
    const response: ConfirmationDecisionResponse =
      await this.send<ConfirmationDecisionResponse>(
        'POST',
        `/api/mobile/confirmations/${encodeURIComponent(requestId)}/decision`,
        JSON.stringify({ status: status }),
        true
      )
    if (!response.result ||
      !isAuthoritativeSuccess(response.result.operation) ||
      response.result.operation.authority !== OperationAuthority.BACKEND ||
      response.result.request.requestId !== requestId ||
      response.result.request.status !== status) {
      throw new MobileApiError(0, 'Confirmation decision lacks backend acknowledgement')
    }
    return response.result
  }

  latestSyncState(): SyncState {
    return this.syncState
  }

  private requireBackendAcknowledgement(result: CardMutationResult): void {
    if (!result || !isAuthoritativeSuccess(result.operation) ||
      result.operation.authority !== OperationAuthority.BACKEND) {
      throw new MobileApiError(0, 'Operation lacks backend acknowledgement')
    }
  }

  private preserveCachedAdminPolicy(mapped: DigitalCard): DigitalCard {
    let current: DigitalCard | null = null
    this.cachedCards.forEach((card: DigitalCard) => {
      if (card.id === mapped.id) {
        current = card
      }
    })
    return current ? preserveAdminConfirmationRequirement(current, mapped) : mapped
  }

  private cacheCard(card: DigitalCard): void {
    let replaced: boolean = false
    this.cachedCards = this.cachedCards.map((item: DigitalCard) => {
      if (item.id === card.id) {
        replaced = true
        return card
      }
      return item
    })
    if (!replaced) {
      this.cachedCards.push(card)
    }
  }

  private async send<T>(
    method: string,
    path: string,
    body: string,
    authenticated: boolean
  ): Promise<T> {
    const request: MobileHttpRequest = {
      method: method,
      path: path,
      body: body,
      accessToken: authenticated ? this.sessionStore.accessToken() : ''
    }
    const response: MobileHttpResponse = await this.transport.send(request)
    if (response.statusCode === 401) {
      await this.sessionStore.clear()
      throw new MobileApiError(401, 'Mobile session expired')
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new MobileApiError(response.statusCode, 'Mobile API request failed')
    }
    if (response.body.length === 0) {
      throw new MobileApiError(response.statusCode, 'Mobile API response is empty')
    }
    try {
      return JSON.parse(response.body) as T
    } catch (error) {
      throw new MobileApiError(response.statusCode, 'Mobile API response is invalid')
    }
  }
}
