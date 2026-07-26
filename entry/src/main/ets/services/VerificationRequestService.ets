import { common, wantAgent } from '@kit.AbilityKit'
import { notificationManager } from '@kit.NotificationKit'

export interface SleVerificationRequest {
  cardId: string
  randomCode: string
}

export class VerificationRequestService {
  static async receive(context: common.UIAbilityContext, request: SleVerificationRequest): Promise<void> {
    AppStorage.setOrCreate<boolean>('verificationPending', false)
    AppStorage.setOrCreate<string>('verificationCardId', '2')
    AppStorage.setOrCreate<string>('verificationRandomCode', '')
    AppStorage.set<string>('verificationCardId', request.cardId)
    AppStorage.set<string>('verificationRandomCode', request.randomCode)
    AppStorage.set<boolean>('verificationPending', true)

    try {
      const agent = await wantAgent.getWantAgent({
        wants: [
          {
            bundleName: 'com.slekey.app',
            abilityName: 'EntryAbility',
            parameters: {
              openVerification: true,
              verificationCardId: request.cardId,
              verificationRandomCode: request.randomCode
            }
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 2201,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      })

      const notificationRequest: notificationManager.NotificationRequest = {
        id: 2201,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        tapDismissed: true,
        wantAgent: agent,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'SleKey 二次验证',
            text: '收到新的 SLE 连接验证请求，点击进入确认。'
          }
        }
      }

      await notificationManager.publish(notificationRequest)
    } catch (error) {
      console.error(`Unable to publish verification notification: ${JSON.stringify(error)}`)
    }
  }
}
