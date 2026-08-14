import { ConfirmationRequest } from '../models/ConfirmationRequest'
import {
  CardMutationResult,
  CardPreferenceUpdate,
  MobileCardAction
} from '../models/MobileOperation'
import { SyncState } from '../models/SyncState'

export interface MobileBackendService {
  updateCardPreferences(
    cardId: string,
    update: CardPreferenceUpdate
  ): Promise<CardMutationResult>
  performCardAction(
    cardId: string,
    action: MobileCardAction
  ): Promise<CardMutationResult>
  listPendingConfirmations(): Promise<ConfirmationRequest[]>
  latestSyncState(): SyncState
}
