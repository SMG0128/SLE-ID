import {
  deserializeWalletState,
  emptyWalletPersistenceState,
  serializeWalletState,
  WalletPersistenceState
} from '../models/WalletPersistence'
import { WalletPersistenceService } from './WalletPersistenceService'

export class InMemoryWalletPersistence implements WalletPersistenceService {
  private serializedState: string = ''
  failNextSave: boolean = false

  async load(): Promise<WalletPersistenceState> {
    if (this.serializedState.length === 0) {
      return emptyWalletPersistenceState()
    }
    return deserializeWalletState(this.serializedState)
  }

  async save(state: WalletPersistenceState): Promise<void> {
    if (this.failNextSave) {
      this.failNextSave = false
      throw new Error('Wallet persistence failure')
    }
    this.serializedState = serializeWalletState(state)
  }
}
