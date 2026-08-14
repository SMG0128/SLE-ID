import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  ConfirmationPersistenceState,
  deserializeConfirmationState,
  serializeConfirmationState
} from '../models/ConfirmationPersistence'
import { ConfirmationPersistenceService } from './ConfirmationPersistenceService'

export class PreferencesConfirmationPersistence implements ConfirmationPersistenceService {
  private readonly context: common.UIAbilityContext
  private readonly preferenceName: string = 'sle_id_mobile_confirmations'
  private readonly stateKey: string = 'confirmation_state_v1'

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<ConfirmationPersistenceState> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        this.context,
        { name: this.preferenceName }
      )
      const serialized: string = await store.get(this.stateKey, '') as string
      return deserializeConfirmationState(serialized)
    } catch (error) {
      throw new Error('Unable to load confirmation cache')
    }
  }

  async save(state: ConfirmationPersistenceState): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        this.context,
        { name: this.preferenceName }
      )
      await store.put(this.stateKey, serializeConfirmationState(state))
      await store.flush()
    } catch (error) {
      throw new Error('Unable to save confirmation cache')
    }
  }
}
