import { ConfirmationRequest } from '../models/ConfirmationRequest'
import {
  MobileWebSocketEnvelope,
  MobileWebSocketMessageType,
  MobileWebSocketRouteResult
} from '../models/MobileWebSocketMessage'

export type ConfirmationMessageHandler = (request: ConfirmationRequest) => Promise<void>
export type CardChangeMessageHandler = (cardId: string, serverRevision: string) => Promise<void>

export class MobileWebSocketRouter {
  private subjectId: string
  private readonly confirmationHandler: ConfirmationMessageHandler
  private readonly cardChangeHandler: CardChangeMessageHandler

  constructor(
    subjectId: string,
    confirmationHandler: ConfirmationMessageHandler,
    cardChangeHandler: CardChangeMessageHandler
  ) {
    this.subjectId = subjectId
    this.confirmationHandler = confirmationHandler
    this.cardChangeHandler = cardChangeHandler
  }

  setSubjectId(subjectId: string): void {
    this.subjectId = subjectId
  }

  async route(serialized: string): Promise<MobileWebSocketRouteResult> {
    let envelope: MobileWebSocketEnvelope
    try {
      envelope = JSON.parse(serialized) as MobileWebSocketEnvelope
    } catch (error) {
      return MobileWebSocketRouteResult.INVALID
    }
    if (!envelope || !envelope.type ||
      (this.subjectId.length > 0 && envelope.subjectId !== this.subjectId)) {
      return envelope && envelope.subjectId !== this.subjectId ?
        MobileWebSocketRouteResult.SUBJECT_MISMATCH :
        MobileWebSocketRouteResult.INVALID
    }
    if (envelope.type === MobileWebSocketMessageType.CONFIRMATION_REQUEST) {
      if (!envelope.confirmation ||
        envelope.confirmation.requestId.length === 0) {
        return MobileWebSocketRouteResult.INVALID
      }
      await this.confirmationHandler(envelope.confirmation)
      return MobileWebSocketRouteResult.CONFIRMATION
    }
    if (envelope.type === MobileWebSocketMessageType.CARD_STATUS ||
      envelope.type === MobileWebSocketMessageType.CARD_REVOKED) {
      await this.cardChangeHandler(envelope.cardId, envelope.serverRevision)
      return MobileWebSocketRouteResult.CARD_CHANGE
    }
    return MobileWebSocketRouteResult.UNSUPPORTED
  }
}

export function boundedReconnectDelay(attempt: number): number {
  const delays: number[] = [1000, 2000, 4000, 8000, 16000, 30000]
  const index: number = Math.max(0, Math.min(attempt, delays.length - 1))
  return delays[index]
}
