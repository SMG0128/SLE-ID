import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { notificationManager } from '@kit.NotificationKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { ImmersiveLightEffect } from '../common/ImmersiveEffect'
import { VerificationRequestService } from '../services/VerificationRequestService'
import { NearLinkConnectionService } from '../services/NearLinkConnectionService'
import { MobileRuntime } from '../runtime/MobileRuntime'
import { MobilePairRequest } from '../models/MobileSession'

export default class EntryAbility extends UIAbility {
  private immersiveEffect: ImmersiveLightEffect = ImmersiveLightEffect.getInstance()
  private backendAddressOverride: string = ''
  private pairingRequest: MobilePairRequest | null = null

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    NearLinkConnectionService.getInstance().setContext(this.context)
    AppStorage.setOrCreate<boolean>('verificationPending', false)
    AppStorage.setOrCreate<string>('verificationCardId', '2')
    AppStorage.setOrCreate<string>('verificationRandomCode', '')
    this.applyVerificationWant(want)
    this.applyMobileBootstrapWant(want)
    hilog.info(0x0000, 'SleKey', 'Ability onCreate')
  }

  onDestroy(): void {
    NearLinkConnectionService.getInstance().dispose().catch(() => {
      hilog.warn(0x0000, 'SleKey', 'NearLink cleanup failed.')
    })
    MobileRuntime.dispose().catch(() => {
      hilog.warn(0x0000, 'SleKey', 'Mobile runtime cleanup failed.')
    })
    hilog.info(0x0000, 'SleKey', 'Ability onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'SleKey', 'Ability onWindowStageCreate')

    this.configureDeviceOrientation(windowStage)

    notificationManager.requestEnableNotification(this.context).catch(() => {
      hilog.warn(0x0000, 'SleKey', 'Notification permission is not enabled.')
    })

    // Initialize the immersive light effect.
    this.immersiveEffect.init(windowStage).then(() => {
      hilog.info(0x0000, 'SleKey', 'Immersive mode initialized')
    })

    MobileRuntime.initialize(this.context, this.backendAddressOverride).then(() => {
      this.backendAddressOverride = ''
      return this.pairIfRequested()
    }).then(() => {
      this.loadApplicationContent(windowStage)
    }).catch((error: Error) => {
      hilog.error(0x0000, 'SleKey',
        `Failed to initialize mobile runtime: ${String(error)}`)
      this.loadApplicationContent(windowStage)
    })
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'SleKey', 'Ability onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(0x0000, 'SleKey', 'Ability onForeground')
    MobileRuntime.onForeground()
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyVerificationWant(want)
    this.applyMobileBootstrapWant(want)
    this.applyUpdatedMobileBootstrap().catch((error: Error) => {
      hilog.warn(0x0000, 'SleKey',
        `Updated mobile bootstrap failed: ${String(error)}`)
    })
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
    MobileRuntime.onBackground()
  }

  public handleSleVerificationRequest(cardId: string, randomCode: string): void {
    VerificationRequestService.receive(this.context, { cardId: cardId, randomCode: randomCode }).catch(() => {
      hilog.error(0x0000, 'SleKey', 'Failed to publish the verification request.')
    })
  }

  private loadApplicationContent(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'SleKey', 'Failed to load content. Cause: %{public}s', JSON.stringify(err))
        return
      }
      hilog.info(0x0000, 'SleKey', 'Succeeded in loading content.')
    })
  }

  private configureDeviceOrientation(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      const orientation: window.Orientation = deviceInfo.deviceType === 'tablet' ?
        window.Orientation.AUTO_ROTATION : window.Orientation.PORTRAIT
      return mainWindow.setPreferredOrientation(orientation)
    }).catch(() => {
      hilog.warn(0x0000, 'SleKey', 'Unable to configure device orientation.')
    })
  }

  private applyMobileBootstrapWant(want: Want): void {
    if (!want.parameters) {
      return
    }
    const backendAddress: string = want.parameters['backendBaseUrl'] as string
    if (backendAddress) {
      this.backendAddressOverride = backendAddress
    }
    const pairingCode: string = want.parameters['mobilePairingCode'] as string
    const deviceId: string = want.parameters['mobileDeviceId'] as string
    const deviceName: string = want.parameters['mobileDeviceName'] as string
    if (pairingCode && deviceId && deviceName) {
      this.pairingRequest = {
        pairingCode: pairingCode,
        deviceId: deviceId,
        deviceName: deviceName
      }
    }
  }

  private async pairIfRequested(): Promise<void> {
    if (!this.pairingRequest) {
      return
    }
    const request: MobilePairRequest = this.pairingRequest
    this.pairingRequest = null
    await MobileRuntime.pair(request)
  }

  private async applyUpdatedMobileBootstrap(): Promise<void> {
    if (this.backendAddressOverride.length > 0) {
      await MobileRuntime.configureBackendAddress(this.backendAddressOverride)
      this.backendAddressOverride = ''
    }
    await this.pairIfRequested()
  }
}
