import { ConfirmationPersistenceState } from '../models/ConfirmationPersistence'

export interface ConfirmationPersistenceService {
  load(): Promise<ConfirmationPersistenceState>
  save(state: ConfirmationPersistenceState): Promise<void>
}
