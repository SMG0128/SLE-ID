import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { notificationManager } from '@kit.NotificationKit'
import { ImmersiveLightEffect } from '../common/ImmersiveEffect'
import { VerificationRequestService } from '../services/VerificationRequestService'
import { NearLinkConnectionService } from '../services/NearLinkConnectionService'

export default class EntryAbility extends UIAbility {
  private immersiveEffect: ImmersiveLightEffect = ImmersiveLightEffect.getInstance()

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    NearLinkConnectionService.getInstance().setContext(this.context)
    AppStorage.setOrCreate<boolean>('verificationPending', false)
    AppStorage.setOrCreate<string>('verificationCardId', '2')
    AppStorage.setOrCreate<string>('verificationRandomCode', '')
    this.applyVerificationWant(want)
    hilog.info(0x0000, 'SleKey', 'Ability onCreate')
  }

  onDestroy(): void {
    NearLinkConnectionService.getInstance().dispose().catch(() => {
      hilog.warn(0x0000, 'SleKey', 'NearLink cleanup failed.')
    })
    hilog.info(0x0000, 'SleKey', 'Ability onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'SleKey', 'Ability onWindowStageCreate')

    notificationManager.requestEnableNotification(this.context).catch(() => {
      hilog.warn(0x0000, 'SleKey', 'Notification permission is not enabled.')
    })

    // Initialize the immersive light effect.
    this.immersiveEffect.init(windowStage).then(() => {
      hilog.info(0x0000, 'SleKey', 'Immersive mode initialized')
    })

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'SleKey', 'Failed to load content. Cause: %{public}s', JSON.stringify(err))
        return
      }
      hilog.info(0x0000, 'SleKey', 'Succeeded in loading content.')
    })
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'SleKey', 'Ability onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(0x0000, 'SleKey', 'Ability onForeground')
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyVerificationWant(want)
  }

  private applyVerificationWant(want: Want): void {
    if (!want.parameters || want.parameters['openVerification'] !== true) {
      return
    }

    const cardId = want.parameters['verificationCardId'] as string
    const randomCode = want.parameters['verificationRandomCode'] as string
    AppStorage.set<string>('verificationCardId', cardId ? cardId : '2')
    AppStorage.set<string>('verificationRandomCode', randomCode ? randomCode : '')
    AppStorage.set<boolean>('verificationPending', true)
  }

  onBackground(): void {
    hilog.info(0x0000, 'SleKey', 'Ability onBackground')
  }

  public handleSleVerificationRequest(cardId: string, randomCode: string): void {
    VerificationRequestService.receive(this.context, { cardId: cardId, randomCode: randomCode }).catch(() => {
      hilog.error(0x0000, 'SleKey', 'Failed to publish the verification request.')
    })
  }
}
