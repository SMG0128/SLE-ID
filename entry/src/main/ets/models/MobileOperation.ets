import { DigitalCard } from './DigitalCard'
import { OperationReceipt } from './Operation'
import { OperationState } from './Operation'

export enum MobileCardAction {
  FREEZE = 'freeze',
  LOST = 'lost',
  RESTORE = 'restore',
  UNBIND = 'unbind'
}

export interface CardPreferenceUpdate {
  nickname?: string
  category?: string
  userConfirmEnabled?: boolean
}

export interface CardMutationResult {
  card: DigitalCard | null
  operation: OperationReceipt
}

export enum PendingMobileMutationKind {
  PREFERENCES = 'preferences',
  ACTION = 'action'
}

export interface PendingMobileMutation {
  operationId: string
  kind: PendingMobileMutationKind
  cardId: string
  preferenceUpdate: CardPreferenceUpdate | null
  action: MobileCardAction | null
  createdAt: string
  lastAttemptAt: string
  attemptCount: number
  state: OperationState
}
