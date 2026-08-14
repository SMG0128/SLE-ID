import * as Theme from '../common/Theme'
import { Credential } from '../models/Credential'
import {
  PhysicalCard,
  PhysicalCardConnectionState,
  PhysicalCardDiscoveryState
} from '../models/PhysicalCard'
import { CredentialRemovalResult } from '../models/PhysicalCardOperation'
import { PrimaryPhysicalCardBindingResult } from '../models/PhysicalCardOperation'
import { DigitalCard } from '../models/DigitalCard'
import { CardStore } from '../stores/CardStore'

@Component
export struct PhysicalCardManagerPage {
  @ObjectLink cardStore: CardStore
  @Link language: string
  @Link showPhysicalCardManagerPage: boolean
  @State pendingCredentialId: string = ''
  @State removingCredential: boolean = false
  @State operationMessage: string = ''
  @State showDiscoveryPicker: boolean = false
  @State bindingPhysicalCard: boolean = false

  aboutToDisappear(): void {
    this.cardStore.stopPhysicalCardDiscovery()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.TopAppBar()

        Scroll() {
          Column() {
            this.PrimaryPhysicalCardSection()
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .padding({
            left: Theme.CONTAINER_MARGIN,
            right: Theme.CONTAINER_MARGIN,
            bottom: 40
          })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.SURFACE)
      .padding({ top: Theme.STATUS_BAR_PADDING })

      if (this.pendingCredentialId.length > 0) {
        this.DeleteConfirmation()
      }

      if (this.showDiscoveryPicker) {
        this.DiscoveryPicker()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TopAppBar() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(20)
        .fontColor([Theme.PRIMARY])
        .onClick(() => {
          this.cardStore.stopPhysicalCardDiscovery()
          this.showPhysicalCardManagerPage = false
        })

      Text(this.language === 'zh' ? 'WS63 实体通行证' : 'WS63 Pass')
        .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE)
        .margin({ left: Theme.SPACING_MD })

      Blank()

      Button(this.cardStore.primaryPhysicalCard ?
        (this.language === 'zh' ? '更换' : 'Replace') :
        (this.language === 'zh' ? '绑定' : 'Bind'))
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontColor(Theme.PRIMARY)
        .backgroundColor('rgba(70, 72, 212, 0.08)')
        .borderRadius(Theme.RADIUS_FULL)
        .onClick(() => {
          this.openDiscoveryPicker()
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN })
    .backgroundColor('rgba(248, 249, 250, 0.8)')
    .backdropBlur(40)
    .borderWidth({ bottom: 1 })
    .borderColor('rgba(199, 196, 215, 0.3)')
  }

  @Builder
  PrimaryPhysicalCardSection() {
    Column() {
      Text(this.language === 'zh' ? '主要实体通行证' : 'Primary physical pass')
        .fontSize(Theme.LABEL_MD_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .alignSelf(ItemAlign.Start)
        .margin({ top: Theme.SPACING_LG, bottom: Theme.SPACING_MD })

      if (this.cardStore.primaryPhysicalCard) {
        this.PhysicalCardItem(this.cardStore.primaryPhysicalCard)
      } else {
        Column() {
          Text(this.language === 'zh' ? '尚未绑定 WS63 实体卡' : 'No WS63 card bound')
            .fontSize(Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE)
          Text(this.language === 'zh' ?
            '发现并绑定一张实体卡后，多张数字许可会作为 Credential 写入同一张主卡。' :
            'Bind one card, then store multiple digital authorizations on it as credentials.')
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .textAlign(TextAlign.Center)
            .margin({ top: Theme.SPACING_SM })
          Button(this.language === 'zh' ? '发现并绑定' : 'Discover and bind')
            .margin({ top: Theme.SPACING_LG })
            .backgroundColor(Theme.PRIMARY)
            .onClick(() => {
              this.openDiscoveryPicker()
            })
        }
        .width('100%')
        .padding(Theme.SPACING_XL)
        .backgroundColor(Theme.SURFACE_CONTAINER_LOWEST)
        .borderRadius(Theme.RADIUS_LG)
      }

      if (this.operationMessage.length > 0) {
        Text(this.operationMessage)
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .margin({ top: Theme.SPACING_MD })
      }
    }
    .width('100%')
  }

  @Builder
  PhysicalCardItem(card: PhysicalCard) {
    Column() {
      Row() {
        Column() {
          Text(card.displayName)
            .fontSize(Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE)

          Text(card.cardAnonId)
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(this.connectionText(card.connectionState))
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(card.connectionState === PhysicalCardConnectionState.CONNECTED ?
            Theme.PRIMARY : Theme.ON_SURFACE_VARIANT)
      }
      .width('100%')

      Row() {
        Text(this.language === 'zh' ? '容量' : 'Capacity')
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
        Blank()
        Text(`${card.usedCapacity} / ${card.totalCapacity}`)
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE)
      }
      .width('100%')
      .margin({ top: Theme.SPACING_MD })

      Text(this.language === 'zh' ?
        `${card.credentialIds.length} 份凭证` :
        `${card.credentialIds.length} credentials`)
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .width('100%')
        .margin({ top: Theme.SPACING_XS, bottom: Theme.SPACING_SM })

      ForEach(card.credentialIds, (credentialId: string) => {
        this.CredentialRow(credentialId)
      }, (credentialId: string) => credentialId)
    }
    .width('100%')
    .padding(Theme.SPACING_LG)
    .margin({ bottom: Theme.SPACING_MD })
    .backgroundColor(Theme.SURFACE_CONTAINER_LOWEST)
    .borderRadius(Theme.RADIUS_LG)
    .borderWidth(1)
    .borderColor('rgba(199, 196, 215, 0.18)')
  }

  @Builder
  CredentialRow(credentialId: string) {
    Row() {
      Column() {
        Text(this.credentialCardName(credentialId))
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE)
        Text(this.maskCredentialId(credentialId))
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Button(this.language === 'zh' ? '删除' : 'Remove')
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontColor(Theme.ERROR)
        .backgroundColor('rgba(186, 26, 26, 0.08)')
        .borderRadius(Theme.RADIUS_FULL)
        .onClick(() => {
          this.operationMessage = ''
          this.pendingCredentialId = credentialId
        })
    }
    .width('100%')
    .padding({ top: Theme.SPACING_SM, bottom: Theme.SPACING_SM })
  }

  @Builder
  DiscoveryPicker() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('120%')
        .height('120%')
        .backgroundColor('rgba(25, 28, 29, 0.46)')
        .backdropBlur(12)
        .onClick(() => {
          if (!this.bindingPhysicalCard) {
            this.closeDiscoveryPicker()
          }
        })

      Column() {
        Row() {
          Column() {
            Text(this.language === 'zh' ? '发现 WS63 实体卡' : 'Discover WS63 cards')
              .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
              .fontColor(Theme.ON_SURFACE)
            Text(this.discoveryTitle())
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontColor(Theme.ON_SURFACE_VARIANT)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Button(this.cardStore.discoveryState === PhysicalCardDiscoveryState.DISCOVERING ?
            (this.language === 'zh' ? '停止' : 'Stop') :
            (this.language === 'zh' ? '重试' : 'Retry'))
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .enabled(!this.bindingPhysicalCard)
            .onClick(() => {
              if (this.cardStore.discoveryState === PhysicalCardDiscoveryState.DISCOVERING) {
                this.cardStore.stopPhysicalCardDiscovery()
              } else {
                this.cardStore.startPhysicalCardDiscovery()
              }
            })
        }
        .width('100%')

        Text(this.discoveryDescription())
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .margin({ top: Theme.SPACING_MD, bottom: Theme.SPACING_MD })

        Scroll() {
          Column() {
            ForEach(this.cardStore.discoveredPhysicalCards, (card: PhysicalCard) => {
              Row() {
                Column() {
                  Text(card.displayName)
                    .fontSize(Theme.BODY_MD_FONT_SIZE)
                    .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
                    .fontColor(Theme.ON_SURFACE)
                  Text(`${card.cardAnonId} · ${card.usedCapacity}/${card.totalCapacity}`)
                    .fontSize(Theme.LABEL_SM_FONT_SIZE)
                    .fontColor(Theme.ON_SURFACE_VARIANT)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                Button(this.cardStore.primaryPhysicalCard &&
                  this.cardStore.primaryPhysicalCard.physicalCardId === card.physicalCardId ?
                  (this.language === 'zh' ? '当前主卡' : 'Current') :
                  (this.language === 'zh' ? '设为主卡' : 'Use as primary'))
                  .fontSize(Theme.LABEL_SM_FONT_SIZE)
                  .enabled(!this.bindingPhysicalCard &&
                    (!this.cardStore.primaryPhysicalCard ||
                      this.cardStore.primaryPhysicalCard.physicalCardId !== card.physicalCardId))
                  .backgroundColor(Theme.PRIMARY)
                  .onClick(() => {
                    this.bindDiscoveredPhysicalCard(card.physicalCardId).catch(() => {
                      this.bindingPhysicalCard = false
                      this.operationMessage = this.language === 'zh' ?
                        '绑定失败，请稍后重试' : 'Binding failed. Try again later.'
                    })
                  })
              }
              .width('100%')
              .padding(Theme.SPACING_MD)
              .margin({ bottom: Theme.SPACING_SM })
              .backgroundColor(Theme.SURFACE_CONTAINER_LOWEST)
              .borderRadius(Theme.RADIUS_MD)
              .borderWidth(1)
              .borderColor('rgba(199, 196, 215, 0.2)')
            }, (card: PhysicalCard) => card.physicalCardId)
          }
          .width('100%')
        }
        .height(320)
        .scrollBar(BarState.Off)

        Button(this.language === 'zh' ? '取消' : 'Cancel')
          .width('100%')
          .height(48)
          .margin({ top: Theme.SPACING_MD })
          .enabled(!this.bindingPhysicalCard)
          .onClick(() => {
            this.closeDiscoveryPicker()
          })
      }
      .width('92%')
      .constraintSize({ maxWidth: 500, maxHeight: '82%' })
      .padding(Theme.SPACING_LG)
      .backgroundColor('rgba(248, 249, 250, 0.96)')
      .backdropBlur(40)
      .borderRadius(Theme.RADIUS_LG)
      .borderWidth(1)
      .borderColor('rgba(255, 255, 255, 0.75)')
    }
    .width('100%')
    .height('100%')
    .zIndex(90)
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
        .animation({ duration: Theme.ANIMATION_DURATION, curve: Curve.EaseInOut })
    )
  }

  @Builder
  DeleteConfirmation() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(25, 28, 29, 0.46)')
        .backdropBlur(12)
        .onClick(() => {
          if (!this.removingCredential) {
            this.pendingCredentialId = ''
          }
        })

      Column() {
        Text(this.language === 'zh' ? '删除这份凭证？' : 'Remove this credential?')
          .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE)

        Text(this.language === 'zh' ?
          '只会删除当前凭证，实体卡中的其他凭证不会受到影响。' :
          'Only this credential will be removed. Other credentials remain intact.')
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .textAlign(TextAlign.Center)
          .margin({ top: Theme.SPACING_SM, bottom: Theme.SPACING_LG })

        Row({ space: Theme.SPACING_SM }) {
          Button(this.language === 'zh' ? '取消' : 'Cancel')
            .layoutWeight(1)
            .enabled(!this.removingCredential)
            .onClick(() => {
              this.pendingCredentialId = ''
            })

          Button(this.removingCredential ?
            (this.language === 'zh' ? '删除中…' : 'Removing…') :
            (this.language === 'zh' ? '确认删除' : 'Remove'))
            .layoutWeight(1)
            .enabled(!this.removingCredential)
            .backgroundColor(Theme.ERROR)
            .onClick(() => {
              this.confirmRemoveCredential().catch(() => {
                this.removingCredential = false
                this.operationMessage = this.language === 'zh' ?
                  '删除失败，请稍后重试' : 'Removal failed. Try again later.'
              })
            })
        }
        .width('100%')
      }
      .width('88%')
      .padding(Theme.SPACING_LG)
      .backgroundColor('rgba(248, 249, 250, 0.96)')
      .backdropBlur(40)
      .borderRadius(Theme.RADIUS_LG)
    }
    .width('100%')
    .height('100%')
    .zIndex(100)
  }

  private openDiscoveryPicker(): void {
    this.operationMessage = ''
    this.showDiscoveryPicker = true
    this.cardStore.startPhysicalCardDiscovery()
  }

  private closeDiscoveryPicker(): void {
    this.cardStore.stopPhysicalCardDiscovery()
    this.showDiscoveryPicker = false
    this.bindingPhysicalCard = false
  }

  private async bindDiscoveredPhysicalCard(
    physicalCardId: string
  ): Promise<void> {
    if (this.bindingPhysicalCard) {
      return
    }
    this.bindingPhysicalCard = true
    const result: PrimaryPhysicalCardBindingResult =
      await this.cardStore.bindPrimaryPhysicalCard(physicalCardId)
    this.bindingPhysicalCard = false
    if (!result.success) {
      this.operationMessage = this.language === 'zh' ?
        '无法保存主实体卡，请稍后重试' :
        'Unable to save the primary card. Try again later.'
      return
    }
    this.showDiscoveryPicker = false
    this.operationMessage = this.language === 'zh' ?
      '主要 WS63 实体卡已更新' : 'Primary WS63 card updated'
  }

  private async confirmRemoveCredential(): Promise<void> {
    if (this.removingCredential || this.pendingCredentialId.length === 0) {
      return
    }
    this.removingCredential = true
    const result: CredentialRemovalResult =
      await this.cardStore.removeCredentialFromPhysicalCard(
        this.pendingCredentialId
      )
    this.removingCredential = false
    if (!result.success) {
      this.operationMessage = this.language === 'zh' ?
        '删除失败，原凭证已保留' : 'Removal failed. The credential was preserved.'
      this.pendingCredentialId = ''
      return
    }
    this.operationMessage = this.language === 'zh' ?
      '凭证已删除' : 'Credential removed'
    this.pendingCredentialId = ''
  }

  private credentialCardName(credentialId: string): string {
    const credential: Credential | null =
      this.cardStore.getCredential(credentialId)
    if (!credential) {
      return this.language === 'zh' ? '未知数字许可' : 'Unknown authorization'
    }
    let name: string = credential.permissionId
    this.cardStore.cards.forEach((card: DigitalCard) => {
      if (card.permissionId === credential.permissionId) {
        name = card.nickname.length > 0 ? card.nickname : card.name
      }
    })
    return name
  }

  private maskCredentialId(credentialId: string): string {
    if (credentialId.length <= 8) {
      return '****'
    }
    return `****${credentialId.slice(-8)}`
  }

  private connectionText(state: PhysicalCardConnectionState): string {
    if (state === PhysicalCardConnectionState.CONNECTED) {
      return this.language === 'zh' ? '已连接' : 'Connected'
    }
    if (state === PhysicalCardConnectionState.CONNECTING) {
      return this.language === 'zh' ? '连接中' : 'Connecting'
    }
    if (state === PhysicalCardConnectionState.CONNECTION_FAILED) {
      return this.language === 'zh' ? '连接失败' : 'Connection failed'
    }
    return this.language === 'zh' ? '未连接' : 'Disconnected'
  }

  private discoveryTitle(): string {
    if (this.cardStore.discoveryState === PhysicalCardDiscoveryState.DISCOVERING) {
      return this.language === 'zh' ? '正在发现实体卡…' : 'Discovering WS63 cards…'
    }
    if (this.cardStore.discoveryState === PhysicalCardDiscoveryState.NO_DEVICE) {
      return this.language === 'zh' ? '未发现实体卡' : 'No WS63 card found'
    }
    if (this.cardStore.discoveryState === PhysicalCardDiscoveryState.DISCOVERY_FAILED) {
      return this.language === 'zh' ? '发现失败' : 'Discovery failed'
    }
    return this.language === 'zh' ? '虚拟 WS63 实体卡' : 'Virtual WS63 cards'
  }

  private discoveryDescription(): string {
    return this.language === 'zh' ?
      '以下为临时 Mock 发现结果。只有选中的设备会保存为主要实体卡。' :
      'These are temporary Mock discovery results. Only the selected device becomes the primary card.'
  }
}
