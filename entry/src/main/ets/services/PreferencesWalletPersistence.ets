import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  deserializeWalletState,
  serializeWalletState,
  WalletPersistenceState
} from '../models/WalletPersistence'
import { WalletPersistenceService } from './WalletPersistenceService'

export class PreferencesWalletPersistence implements WalletPersistenceService {
  private readonly context: common.UIAbilityContext
  private readonly preferenceName: string = 'sle_id_mobile_wallet'
  private readonly stateKey: string = 'wallet_state_v1'

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<WalletPersistenceState> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        this.context,
        { name: this.preferenceName }
      )
      const serialized: string = await store.get(this.stateKey, '') as string
      return deserializeWalletState(serialized)
    } catch (error) {
      throw new Error('Unable to load wallet cache')
    }
  }

  async save(state: WalletPersistenceState): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        this.context,
        { name: this.preferenceName }
      )
      await store.put(this.stateKey, serializeWalletState(state))
      await store.flush()
    } catch (error) {
      throw new Error('Unable to save wallet cache')
    }
  }
}
