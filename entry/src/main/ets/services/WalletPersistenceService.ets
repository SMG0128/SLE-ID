import { WalletPersistenceState } from '../models/WalletPersistence'

export interface WalletPersistenceService {
  load(): Promise<WalletPersistenceState>
  save(state: WalletPersistenceState): Promise<void>
}
