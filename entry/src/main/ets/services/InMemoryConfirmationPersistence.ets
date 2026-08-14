import {
  ConfirmationPersistenceState,
  deserializeConfirmationState,
  emptyConfirmationPersistenceState,
  serializeConfirmationState
} from '../models/ConfirmationPersistence'
import { ConfirmationPersistenceService } from './ConfirmationPersistenceService'

export class InMemoryConfirmationPersistence implements ConfirmationPersistenceService {
  private serializedState: string = ''

  async load(): Promise<ConfirmationPersistenceState> {
    if (this.serializedState.length === 0) {
      return emptyConfirmationPersistenceState()
    }
    return deserializeConfirmationState(this.serializedState)
  }

  async save(state: ConfirmationPersistenceState): Promise<void> {
    this.serializedState = serializeConfirmationState(state)
  }
}
