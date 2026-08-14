import * as Theme from '../common/Theme'
import { DigitalCard } from '../models/DigitalCard'
import {
  Credential,
  CredentialBindingStatus,
  CredentialCondition
} from '../models/Credential'
import {
  PhysicalCard,
  PhysicalCardConnectionState,
  PhysicalCardDiscoveryState
} from '../models/PhysicalCard'
import {
  CredentialWriteResult,
  PhysicalCardConnectionResult,
  PhysicalCardFailureReason,
  PrimaryPhysicalCardBindingResult
} from '../models/PhysicalCardOperation'
import { CardStore } from '../stores/CardStore'

@Component
export struct CardDetailPage {
  @ObjectLink cardStore: CardStore
  @Link language: string
  @Link showCardDetailPage: boolean
  @Link selectedCardId: string
  @Prop isTablet: boolean = false
  @Prop windowWidth: number = 0
  @State showWriteCardModal: boolean = false
  @State selectedPhysicalCardId: string = ''
  @State physicalOperationMessage: string = ''
  private physicalOperationId: number = 0

  aboutToDisappear(): void {
    this.stopPhysicalCardFlow()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // Top App Bar
        this.TopAppBar()

        if (this.usesSplitLayout()) {
          this.TabletDetailContent()
        } else {
          // Phone keeps one vertically scrolling detail surface.
          Scroll() {
            this.PhoneDetailContent()
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.SURFACE)
      .padding({ top: Theme.STATUS_BAR_PADDING })

      if (this.showWriteCardModal) {
        this.WriteCardModal()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PhoneDetailContent() {
    Column() {
      this.CardVisualization()
      this.InformationSection()
      this.CardSettingsSection()
      this.CredentialBindingSection()
      this.SecuritySection()
      this.DangerZone()
    }
    .width('100%')
    .padding({
      left: Theme.CONTAINER_MARGIN,
      right: Theme.CONTAINER_MARGIN,
      bottom: 40
    })
  }

  @Builder
  TabletDetailContent() {
    Row({ space: Theme.TABLET_CARD_GAP }) {
      Column() {
        this.CardVisualization()
        this.InformationSection()
      }
      .width(this.tabletCardColumnWidth())
      .alignItems(HorizontalAlign.Start)
      .alignSelf(ItemAlign.Start)

      Scroll() {
        Column() {
          this.CredentialBindingSection()
          this.CardSettingsSection()
          this.SecuritySection()
          this.DangerZone()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .height('100%')
      .align(Alignment.TopStart)
      .alignSelf(ItemAlign.Start)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .layoutWeight(1)
    .width('100%')
    .constraintSize({ maxWidth: 1400 })
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
    .padding({
      left: Theme.TABLET_CONTAINER_MARGIN,
      right: Theme.TABLET_CONTAINER_MARGIN,
      bottom: Theme.SPACING_XL
    })
  }

  @Builder
  TopAppBar() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([Theme.PRIMARY])
      }
      .width(40)
      .height(40)
      .borderRadius(Theme.RADIUS_FULL)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('rgba(70, 72, 212, 0.05)')
      .onClick(() => {
        this.stopPhysicalCardFlow()
        this.showCardDetailPage = false
      })

      Text(this.language === 'zh' ? '卡片详情' : 'Card Details')
        .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE)
        .margin({ left: Theme.SPACING_MD })

      Blank()

      SymbolGlyph($r('sys.symbol.questionmark_circle'))
        .fontSize(Theme.ICON_LG)
        .fontColor([Theme.PRIMARY])
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
  CardVisualization() {
    Stack() {
      // Gradient background
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.RightBottom,
          colors: [
            [Theme.PRIMARY, 0],
            [Theme.SECONDARY, 0.5],
            [Theme.TERTIARY_CONTAINER, 1]
          ]
        })

      // Holographic overlay
      Column()
        .width('100%')
        .height('100%')
        .opacity(0.4)

      // Card content
      Column() {
        // Top section
        Row() {
          Column() {
            Text(this.currentCard().issuer)
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
              .fontColor('rgba(255, 255, 255, 0.8)')
              .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)

            Text(this.currentCard().name)
              .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
              .fontColor(Color.White)
              .letterSpacing(Theme.HEADLINE_MD_LETTER_SPACING)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          SymbolGlyph($r('sys.symbol.creditcard'))
            .fontSize(Theme.ICON_XXL)
            .fontColor([Color.White])
        }
        .width('100%')

        Blank()

        // Bottom section
        Column() {
          Text(this.maskedCardNumber())
            .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Color.White)
            .letterSpacing(0.2)

          Row() {
            Text(this.currentCard().nickname.length > 0 ? this.currentCard().nickname : this.currentCard().name)
              .fontSize(Theme.LABEL_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_MEDIUM)
              .fontColor(Color.White)

            Blank()

            Stack() {
              SymbolGlyph($r('sys.symbol.creditcard'))
                .fontSize(Theme.ICON_SM)
                .fontColor([Color.White])
            }
            .width(32)
            .height(32)
            .borderRadius(Theme.RADIUS_FULL)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .backdropBlur(8)
            .alignContent(Alignment.Center)
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding(Theme.SPACING_LG)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .aspectRatio(Theme.CARD_ASPECT_RATIO)
    .borderRadius(Theme.RADIUS_LG)
    .shadow({
      radius: 20,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 4
    })
    .clip(true)
  }

  @Builder
  InformationSection() {
    Column() {
      Text(this.language === 'zh' ? '信息' : 'INFORMATION')
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
        .padding({ left: Theme.SPACING_BASE })
        .margin({ bottom: Theme.SPACING_MD })
        .alignSelf(ItemAlign.Start)

      Column() {
        // Issuer row
        Row() {
          Row() {
            Stack() {
              SymbolGlyph($r('sys.symbol.creditcard'))
                .fontSize(Theme.ICON_MD)
                .fontColor([Theme.PRIMARY])
            }
            .width(40)
            .height(40)
            .borderRadius(Theme.RADIUS_FULL)
            .backgroundColor('rgba(70, 72, 212, 0.1)')
            .alignContent(Alignment.Center)

            Text(this.language === 'zh' ? '发行方' : 'Issuer')
              .fontSize(Theme.BODY_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_REGULAR)
              .fontColor(Theme.ON_SURFACE)
              .margin({ left: Theme.SPACING_MD })
          }

          Blank()

          Text(this.currentCard().issuer)
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_REGULAR)
            .fontColor(Theme.ON_SURFACE_VARIANT)
        }
        .width('100%')
        .padding(Theme.SPACING_MD)
        .alignItems(VerticalAlign.Center)

        Divider()
          .color('rgba(199, 196, 215, 0.1)')
          .margin({ left: Theme.SPACING_MD, right: Theme.SPACING_MD })

        // Card ID row
        Row() {
          Row() {
            Stack() {
              SymbolGlyph($r('sys.symbol.creditcard'))
                .fontSize(Theme.ICON_MD)
                .fontColor([Theme.TERTIARY])
            }
            .width(40)
            .height(40)
            .borderRadius(Theme.RADIUS_FULL)
            .backgroundColor('rgba(75, 90, 155, 0.1)')
            .alignContent(Alignment.Center)

            Text(this.language === 'zh' ? '卡片 ID' : 'Card ID')
              .fontSize(Theme.BODY_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_REGULAR)
              .fontColor(Theme.ON_SURFACE)
              .margin({ left: Theme.SPACING_MD })
          }

          Blank()

          Text(this.maskedCardNumber())
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_REGULAR)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .fontFamily('monospace')
        }
        .width('100%')
        .padding(Theme.SPACING_MD)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .backgroundColor(Theme.SURFACE_CONTAINER_LOWEST)
      .borderRadius(Theme.RADIUS_LG)
      .borderWidth(1)
      .borderColor('rgba(199, 196, 215, 0.1)')
      .shadow({
        radius: 20,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 4
      })
    }
    .width('100%')
    .margin({ top: Theme.SPACING_XL })
  }

  @Builder
  CardSettingsSection() {
    Column() {
      Text(this.language === 'zh' ? '卡片设置' : 'CARD SETTINGS')
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
        .padding({ left: Theme.SPACING_BASE })
        .margin({ bottom: Theme.SPACING_MD })
        .alignSelf(ItemAlign.Start)

      Column() {
        Column() {
          Text(this.language === 'zh' ? '昵称' : 'Nickname')
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .alignSelf(ItemAlign.Start)

          TextInput({
            text: this.currentCard().nickname,
            placeholder: this.language === 'zh' ? '默认使用卡片名称' : 'Defaults to the card name'
          })
            .width('100%')
            .height(44)
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontColor(Theme.ON_SURFACE)
            .backgroundColor(Theme.SURFACE_CONTAINER_LOW)
            .borderRadius(Theme.RADIUS_SM)
            .margin({ top: Theme.SPACING_XS })
            .onChange((value: string) => {
              this.updateNickname(value)
            })
        }
        .width('100%')
        .padding(Theme.SPACING_MD)

        Divider()
          .color('rgba(199, 196, 215, 0.1)')
          .margin({ left: Theme.SPACING_MD, right: Theme.SPACING_MD })

        Column() {
          Text(this.language === 'zh' ? '类别' : 'Category')
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .alignSelf(ItemAlign.Start)

          TextInput({
            text: this.currentCard().category,
            placeholder: this.language === 'zh' ? '输入自定义类别' : 'Enter a custom category'
          })
            .width('100%')
            .height(44)
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontColor(Theme.ON_SURFACE)
            .backgroundColor(Theme.SURFACE_CONTAINER_LOW)
            .borderRadius(Theme.RADIUS_SM)
            .margin({ top: Theme.SPACING_XS })
            .onChange((value: string) => {
              this.updateCategory(value)
            })
        }
        .width('100%')
        .padding(Theme.SPACING_MD)

        Divider()
          .color('rgba(199, 196, 215, 0.1)')
          .margin({ left: Theme.SPACING_MD, right: Theme.SPACING_MD })

        Row() {
          Column() {
            Text(this.language === 'zh' ? '启用卡片' : 'Enable Card')
              .fontSize(Theme.BODY_MD_FONT_SIZE)
              .fontColor(Theme.ON_SURFACE)

            Text(this.language === 'zh' ? '控制卡片是否在主页显示为可用' : 'Controls whether the card is available on the home screen')
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontColor(Theme.ON_SURFACE_VARIANT)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.cardStore.isCardEnabled(this.currentCard()) })
            .selectedColor(Theme.PRIMARY)
            .switchPointColor(Color.White)
            .width(44)
            .height(24)
            .onChange((isOn: boolean) => {
              this.updateEnabled(isOn)
            })
        }
        .width('100%')
        .padding(Theme.SPACING_MD)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .backgroundColor(Theme.SURFACE_CONTAINER_LOWEST)
      .borderRadius(Theme.RADIUS_LG)
      .borderWidth(1)
      .borderColor('rgba(199, 196, 215, 0.1)')
      .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 })
      .clip(true)
    }
    .width('100%')
    .margin({ top: Theme.SPACING_XL })
  }

  @Builder
  CredentialBindingSection() {
    Column() {
      Text(this.language === 'zh' ? '实体卡凭证' : 'PHYSICAL CARD CREDENTIAL')
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
        .padding({ left: Theme.SPACING_BASE })
        .margin({ bottom: Theme.SPACING_MD })
        .alignSelf(ItemAlign.Start)

      Column() {
        Row() {
          Column() {
            Text(this.bindingStatusText())
              .fontSize(Theme.TITLE_LG_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
              .fontColor(Theme.ON_SURFACE)

            Text(this.bindingDescription())
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontColor(Theme.ON_SURFACE_VARIANT)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          SymbolGlyph($r('sys.symbol.creditcard'))
            .fontSize(Theme.ICON_XL)
            .fontColor([Theme.PRIMARY])
        }
        .width('100%')

        if (this.currentCard().credentialBindingStatus ===
          CredentialBindingStatus.WRITTEN) {
          this.WrittenCredentialDetails()
        }

        Button(this.currentCard().credentialBindingStatus ===
          CredentialBindingStatus.WRITTEN ?
          (this.language === 'zh' ? '查看实体卡' : 'View physical card') :
          (this.language === 'zh' ? '写入实体卡' : 'Write to WS63'))
          .width('100%')
          .height(48)
          .margin({ top: Theme.SPACING_LG })
          .backgroundColor(Theme.PRIMARY)
          .borderRadius(Theme.RADIUS_FULL)
          .onClick(() => {
            this.openWriteCardFlow()
          })
      }
      .width('100%')
      .padding(Theme.SPACING_LG)
      .backgroundColor(Theme.SURFACE_CONTAINER_LOWEST)
      .borderRadius(Theme.RADIUS_LG)
      .borderWidth(1)
      .borderColor('rgba(199, 196, 215, 0.1)')
      .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 })
    }
    .width('100%')
    .margin({ top: Theme.SPACING_XL })
  }

  @Builder
  WrittenCredentialDetails() {
    Column() {
      this.BindingDetailRow(
        this.language === 'zh' ? '实体卡' : 'Physical card',
        this.boundPhysicalCardName()
      )
      this.BindingDetailRow(
        this.language === 'zh' ? '实体卡编号' : 'Card identifier',
        this.boundPhysicalCardIdentifier()
      )
      this.BindingDetailRow(
        this.language === 'zh' ? '写入时间' : 'Written at',
        this.boundCredentialWrittenAt()
      )
      this.BindingDetailRow(
        this.language === 'zh' ? '凭证版本' : 'Credential version',
        this.boundCredentialVersion()
      )
      this.BindingDetailRow(
        this.language === 'zh' ? '最近校验' : 'Last verified',
        this.boundCredentialVerifiedAt()
      )
    }
    .width('100%')
    .margin({ top: Theme.SPACING_MD })
  }

  @Builder
  BindingDetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontColor(Theme.ON_SURFACE_VARIANT)
      Blank()
      Text(value)
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE)
    }
    .width('100%')
    .padding({ top: Theme.SPACING_XS, bottom: Theme.SPACING_XS })
  }

  @Builder
  WriteCardModal() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(25, 28, 29, 0.46)')
        .backdropBlur(12)
        .onClick(() => {
          if (!this.isWriteBusy()) {
            this.closeWriteCardFlow()
          }
        })

      Column() {
        Row() {
          Column() {
            Text(this.language === 'zh' ? '写入 WS63 实体卡' : 'Write to WS63')
              .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_BOLD)
              .fontColor(Theme.ON_SURFACE)

            Text(this.discoveryStatusText())
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontColor(Theme.ON_SURFACE_VARIANT)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          if (this.cardStore.primaryPhysicalCard) {
            Button(this.language === 'zh' ? '重新连接' : 'Reconnect')
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontColor(Theme.PRIMARY)
              .backgroundColor('rgba(70, 72, 212, 0.08)')
              .enabled(!this.isWriteBusy())
              .onClick(() => {
                this.connectPrimaryPhysicalCard().catch(() => {
                  this.physicalOperationMessage = this.language === 'zh' ?
                    '连接失败，请重试' : 'Connection failed. Try again.'
                })
              })
          } else {
            Button(this.cardStore.discoveryState ===
              PhysicalCardDiscoveryState.DISCOVERING ?
              (this.language === 'zh' ? '停止发现' : 'Stop') :
              (this.language === 'zh' ? '重新发现' : 'Discover'))
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontColor(Theme.PRIMARY)
              .backgroundColor('rgba(70, 72, 212, 0.08)')
              .enabled(!this.isWriteBusy())
              .onClick(() => {
                if (this.cardStore.discoveryState ===
                  PhysicalCardDiscoveryState.DISCOVERING) {
                  this.cardStore.stopPhysicalCardDiscovery()
                } else {
                  this.cardStore.startPhysicalCardDiscovery()
                }
              })
          }
        }
        .width('100%')

        if (this.cardStore.primaryPhysicalCard) {
          this.PrimaryWriteTarget(this.cardStore.primaryPhysicalCard)
        } else {
          Scroll() {
            Column() {
              ForEach(this.cardStore.discoveredPhysicalCards, (card: PhysicalCard) => {
                this.PhysicalCardChoice(card)
              }, (card: PhysicalCard) => card.physicalCardId)
            }
            .width('100%')
          }
          .height(300)
          .scrollBar(BarState.Off)
          .margin({ top: Theme.SPACING_LG })
        }

        if (this.isSelectedPhysicalCardConnected()) {
          this.SelectedPhysicalCardSummary()
        }

        if (this.physicalOperationMessage.length > 0) {
          Text(this.physicalOperationMessage)
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontColor(this.currentCard().credentialBindingStatus ===
              CredentialBindingStatus.WRITTEN ? Theme.PRIMARY : Theme.ERROR)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: Theme.SPACING_MD })
        }

        Row({ space: Theme.SPACING_SM }) {
          Button(this.language === 'zh' ? '取消' : 'Cancel')
            .layoutWeight(1)
            .height(48)
            .onClick(() => {
              this.closeWriteCardFlow()
            })

          Button(this.writePrimaryButtonText())
            .layoutWeight(1)
            .height(48)
            .enabled(this.canConfirmWrite())
            .backgroundColor(Theme.PRIMARY)
            .onClick(() => {
              this.confirmCredentialWrite().catch(() => {
                this.physicalOperationMessage = this.language === 'zh' ?
                  '写入失败，请稍后重试' : 'Write failed. Try again later.'
              })
            })
        }
        .width('100%')
        .margin({ top: Theme.SPACING_LG })
      }
      .width('92%')
      .constraintSize({ maxWidth: 500, maxHeight: '88%' })
      .padding(Theme.SPACING_LG)
      .backgroundColor('rgba(248, 249, 250, 0.96)')
      .backdropBlur(40)
      .borderRadius(Theme.RADIUS_LG)
      .borderWidth(1)
      .borderColor('rgba(255, 255, 255, 0.75)')
      .shadow({ radius: 48, color: 'rgba(0, 0, 0, 0.2)', offsetY: 12 })
    }
    .width('100%')
    .height('100%')
    .zIndex(100)
  }

  @Builder
  PrimaryWriteTarget(card: PhysicalCard) {
    Row() {
      Column() {
        Text(this.language === 'zh' ? '当前主要实体卡' : 'Current primary card')
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
        Text(card.displayName)
          .fontSize(Theme.TITLE_LG_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE)
          .margin({ top: 2 })
        Text(card.cardAnonId)
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text(this.physicalCardConnectionText(card))
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontColor(card.connectionState ===
          PhysicalCardConnectionState.CONNECTED ? Theme.PRIMARY :
          Theme.ON_SURFACE_VARIANT)
    }
    .width('100%')
    .padding(Theme.SPACING_LG)
    .margin({ top: Theme.SPACING_LG })
    .backgroundColor(Theme.SURFACE_CONTAINER_LOWEST)
    .borderRadius(Theme.RADIUS_LG)
    .borderWidth(1)
    .borderColor('rgba(199, 196, 215, 0.2)')
  }

  @Builder
  PhysicalCardChoice(card: PhysicalCard) {
    Row() {
      Column() {
        Text(card.displayName)
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE)
        Text(`${card.usedCapacity}/${card.totalCapacity} · ${card.firmwareVersion}`)
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text(this.physicalCardConnectionText(card))
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontColor(card.connectionState ===
          PhysicalCardConnectionState.CONNECTED ? Theme.PRIMARY :
          Theme.ON_SURFACE_VARIANT)
    }
    .width('100%')
    .padding(Theme.SPACING_MD)
    .margin({ bottom: Theme.SPACING_SM })
    .backgroundColor(this.selectedPhysicalCardId === card.physicalCardId ?
      'rgba(70, 72, 212, 0.12)' : Theme.SURFACE_CONTAINER_LOWEST)
    .borderRadius(Theme.RADIUS_MD)
    .borderWidth(1)
    .borderColor(this.selectedPhysicalCardId === card.physicalCardId ?
      Theme.PRIMARY : 'rgba(199, 196, 215, 0.2)')
    .enabled(!this.isWriteBusy())
    .onClick(() => {
      this.selectAndConnectPhysicalCard(card.physicalCardId).catch(() => {
        this.physicalOperationMessage = this.language === 'zh' ?
          '连接失败，请重试' : 'Connection failed. Try again.'
      })
    })
  }

  @Builder
  SelectedPhysicalCardSummary() {
    Column() {
      this.BindingDetailRow(
        this.language === 'zh' ? '总容量' : 'Total capacity',
        `${this.selectedPhysicalCard()?.totalCapacity || 0}`
      )
      this.BindingDetailRow(
        this.language === 'zh' ? '已使用' : 'Used',
        `${this.selectedPhysicalCard()?.usedCapacity || 0}`
      )
      this.BindingDetailRow(
        this.language === 'zh' ? '已有凭证' : 'Credentials',
        `${this.selectedPhysicalCard()?.credentialIds.length || 0}`
      )
    }
    .width('100%')
    .padding(Theme.SPACING_MD)
    .backgroundColor(Theme.SURFACE_CONTAINER_LOW)
    .borderRadius(Theme.RADIUS_MD)
  }

  @Builder
  SecuritySection() {
    Column() {
      Text(this.language === 'zh' ? '安全' : 'SECURITY')
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
        .padding({ left: Theme.SPACING_BASE })
        .margin({ bottom: Theme.SPACING_MD })
        .alignSelf(ItemAlign.Start)

      Row() {
        Row() {
          Stack() {
            SymbolGlyph($r('sys.symbol.shield_checkered'))
              .fontSize(Theme.ICON_MD)
              .fontColor([Theme.SECONDARY])
          }
          .width(40)
          .height(40)
          .borderRadius(Theme.RADIUS_FULL)
          .backgroundColor('rgba(75, 65, 225, 0.1)')
          .alignContent(Alignment.Center)

          Column() {
            Text(this.language === 'zh' ? '双重身份验证' : 'Two-Factor Authentication')
              .fontSize(Theme.BODY_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_REGULAR)
              .fontColor(Theme.ON_SURFACE)

            Text(this.currentCard().adminConfirmRequired ?
              (this.language === 'zh' ? '管理方要求二次确认' : 'Required by administrator') :
              (this.language === 'zh' ? '需要二次验证' : 'Secondary validation required'))
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
              .fontColor(Theme.ON_SURFACE_VARIANT)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: Theme.SPACING_MD })
        }

        Blank()

        Toggle({ type: ToggleType.Switch, isOn: this.cardStore.requiresConfirmation(this.currentCard()) })
          .selectedColor(Theme.PRIMARY)
          .switchPointColor(Color.White)
          .width(44)
          .height(24)
          .enabled(!this.currentCard().adminConfirmRequired)
          .onChange((isOn: boolean) => {
            this.updateTwoFactor(isOn)
          })
      }
      .width('100%')
      .padding(Theme.SPACING_MD)
      .backgroundColor(Theme.SURFACE_CONTAINER_LOWEST)
      .borderRadius(Theme.RADIUS_LG)
      .borderWidth(1)
      .borderColor('rgba(199, 196, 215, 0.1)')
      .shadow({
        radius: 20,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 4
      })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .margin({ top: Theme.SPACING_XL })
  }

  @Builder
  DangerZone() {
    Column() {
      Button() {
        Row() {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(Theme.ICON_LG)
            .fontColor([Theme.ERROR])
            .margin({ right: Theme.SPACING_MD })

          Text(this.language === 'zh' ? '删除卡片' : 'Delete Card')
            .fontSize(Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ERROR)
        }
      }
      .width('100%')
      .height(56)
      .backgroundColor('rgba(186, 26, 26, 0.2)')
      .borderRadius(Theme.RADIUS_FULL)
      .borderWidth(1)
      .borderColor('rgba(186, 26, 26, 0.1)')
      .type(ButtonType.Normal)

      Text(this.language === 'zh' ? '删除卡片后无法恢复。' : 'Deleting this card is permanent and cannot be undone.')
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor('rgba(70, 69, 84, 0.6)')
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: Theme.SPACING_MD })
    }
    .width('100%')
    .margin({ top: Theme.SPACING_LG + Theme.SPACING_LG })
  }

  private openWriteCardFlow(): void {
    this.physicalOperationId++
    this.physicalOperationMessage = ''
    this.showWriteCardModal = true
    if (this.cardStore.primaryPhysicalCard) {
      this.selectedPhysicalCardId =
        this.cardStore.primaryPhysicalCard.physicalCardId
      this.connectPrimaryPhysicalCard().catch(() => {
        this.physicalOperationMessage = this.language === 'zh' ?
          '连接失败，请重试' : 'Connection failed. Try again.'
      })
    } else {
      this.selectedPhysicalCardId = ''
      this.cardStore.startPhysicalCardDiscovery()
    }
  }

  private closeWriteCardFlow(): void {
    if (this.isWriteBusy()) {
      this.cardStore.cancelCredentialWrite()
    }
    this.physicalOperationId++
    this.cardStore.stopPhysicalCardDiscovery()
    this.cardStore.disconnectPhysicalCard().catch(() => {
      console.error('Unable to disconnect Mock WS63 card')
    })
    this.showWriteCardModal = false
    this.selectedPhysicalCardId = ''
    this.physicalOperationMessage = ''
  }

  private stopPhysicalCardFlow(): void {
    this.physicalOperationId++
    this.cardStore.stopPhysicalCardDiscovery()
    if (this.isWriteBusy()) {
      this.cardStore.cancelCredentialWrite()
    }
    this.cardStore.disconnectPhysicalCard().catch(() => {
      console.error('Unable to disconnect Mock WS63 card')
    })
  }

  private async selectAndConnectPhysicalCard(
    physicalCardId: string
  ): Promise<void> {
    if (this.isWriteBusy()) {
      return
    }
    const operationId: number = ++this.physicalOperationId
    this.selectedPhysicalCardId = physicalCardId
    this.physicalOperationMessage = this.language === 'zh' ?
      '正在绑定主要实体卡…' : 'Binding the primary physical card…'
    const bindingResult: PrimaryPhysicalCardBindingResult =
      await this.cardStore.bindPrimaryPhysicalCard(physicalCardId)
    if (!this.showWriteCardModal || operationId !== this.physicalOperationId) {
      return
    }
    if (!bindingResult.success) {
      this.physicalOperationMessage =
        this.physicalCardErrorText(bindingResult.reason)
      return
    }
    this.selectedPhysicalCardId = physicalCardId
    this.physicalOperationMessage = this.language === 'zh' ?
      '主要实体卡已绑定，正在连接…' :
      'Primary card bound. Connecting…'
    const result: PhysicalCardConnectionResult =
      await this.cardStore.connectPhysicalCard(physicalCardId)
    if (!this.showWriteCardModal || operationId !== this.physicalOperationId) {
      return
    }
    if (result.state === PhysicalCardConnectionState.CONNECTED) {
      this.physicalOperationMessage = this.language === 'zh' ?
        '主要实体卡已连接，请确认容量后写入' :
        'Primary card connected. Review capacity before writing.'
      return
    }
    this.physicalOperationMessage =
      this.physicalCardErrorText(result.reason)
  }

  private async connectPrimaryPhysicalCard(): Promise<void> {
    if (!this.cardStore.primaryPhysicalCard || this.isWriteBusy()) {
      return
    }
    await this.selectAndConnectBoundPrimary(
      this.cardStore.primaryPhysicalCard.physicalCardId
    )
  }

  private async selectAndConnectBoundPrimary(
    physicalCardId: string
  ): Promise<void> {
    const operationId: number = ++this.physicalOperationId
    this.selectedPhysicalCardId = physicalCardId
    this.physicalOperationMessage = this.language === 'zh' ?
      '正在连接主要实体卡…' : 'Connecting to the primary card…'
    const result: PhysicalCardConnectionResult =
      await this.cardStore.connectPhysicalCard(physicalCardId)
    if (!this.showWriteCardModal || operationId !== this.physicalOperationId) {
      return
    }
    if (result.state === PhysicalCardConnectionState.CONNECTED) {
      this.physicalOperationMessage = this.language === 'zh' ?
        '主要实体卡已连接，请确认容量后写入' :
        'Primary card connected. Review capacity before writing.'
      return
    }
    this.physicalOperationMessage =
      this.physicalCardErrorText(result.reason)
  }

  private async confirmCredentialWrite(): Promise<void> {
    if (!this.canConfirmWrite()) {
      return
    }
    const operationId: number = ++this.physicalOperationId
    this.physicalOperationMessage = this.language === 'zh' ?
      '正在生成并写入 Mock Credential…' :
      'Generating and writing the Mock credential…'
    const result: CredentialWriteResult =
      await this.cardStore.writeCardToPrimaryPhysicalCard(
        this.currentCard().id
      )
    if (!this.showWriteCardModal || operationId !== this.physicalOperationId) {
      return
    }
    if (result.status === CredentialBindingStatus.WRITTEN &&
      result.reason === PhysicalCardFailureReason.NONE) {
      this.physicalOperationMessage = this.language === 'zh' ?
        '凭证写入并校验成功' : 'Credential written and verified'
      return
    }
    this.physicalOperationMessage =
      this.physicalCardErrorText(result.reason)
  }

  private selectedPhysicalCard(): PhysicalCard | null {
    return this.cardStore.getPhysicalCard(this.selectedPhysicalCardId)
  }

  private canConfirmWrite(): boolean {
    const physicalCard: PhysicalCard | null = this.selectedPhysicalCard()
    if (!physicalCard || this.isWriteBusy()) {
      return false
    }
    if (this.currentCard().credentialBindingStatus ===
      CredentialBindingStatus.WRITTEN) {
      return false
    }
    return physicalCard.connectionState ===
      PhysicalCardConnectionState.CONNECTED
  }

  private isSelectedPhysicalCardConnected(): boolean {
    const card: PhysicalCard | null = this.selectedPhysicalCard()
    return card !== null &&
      card.connectionState === PhysicalCardConnectionState.CONNECTED
  }

  private isWriteBusy(): boolean {
    return this.cardStore.connectionState === PhysicalCardConnectionState.CONNECTING ||
      this.cardStore.activeWriteStatus === CredentialBindingStatus.WRITING ||
      this.cardStore.activeWriteStatus === CredentialBindingStatus.VERIFYING
  }

  private writePrimaryButtonText(): string {
    if (this.cardStore.activeWriteStatus === CredentialBindingStatus.VERIFYING) {
      return this.language === 'zh' ? '校验中…' : 'Verifying…'
    }
    if (this.cardStore.activeWriteStatus === CredentialBindingStatus.WRITING) {
      return this.language === 'zh' ? '写入中…' : 'Writing…'
    }
    if (this.currentCard().credentialBindingStatus ===
      CredentialBindingStatus.WRITTEN) {
      return this.language === 'zh' ? '已写入' : 'Written'
    }
    return this.language === 'zh' ? '确认写入' : 'Write credential'
  }

  private discoveryStatusText(): string {
    if (this.cardStore.primaryPhysicalCard) {
      if (this.cardStore.connectionState ===
        PhysicalCardConnectionState.CONNECTING) {
        return this.language === 'zh' ?
          '正在连接当前主要实体卡…' : 'Connecting to the current primary card…'
      }
      return this.language === 'zh' ?
        '许可将直接写入当前主要实体卡' :
        'This authorization will be written to the current primary card'
    }
    if (this.cardStore.discoveryState === PhysicalCardDiscoveryState.DISCOVERING) {
      return this.language === 'zh' ? '正在发现虚拟实体卡…' : 'Discovering virtual cards…'
    }
    if (this.cardStore.discoveryState === PhysicalCardDiscoveryState.NO_DEVICE) {
      return this.language === 'zh' ? '未发现实体卡' : 'No physical card found'
    }
    if (this.cardStore.discoveryState ===
      PhysicalCardDiscoveryState.DISCOVERY_FAILED) {
      return this.language === 'zh' ? '实体卡发现失败' : 'Discovery failed'
    }
    return this.language === 'zh' ?
      '请选择一张实体卡并建立 Mock 连接' :
      'Select a card and establish a Mock connection'
  }

  private physicalCardConnectionText(card: PhysicalCard): string {
    if (card.connectionState === PhysicalCardConnectionState.CONNECTED) {
      return this.language === 'zh' ? '已连接' : 'Connected'
    }
    if (card.connectionState === PhysicalCardConnectionState.CONNECTING) {
      return this.language === 'zh' ? '连接中' : 'Connecting'
    }
    if (card.connectionState ===
      PhysicalCardConnectionState.CONNECTION_FAILED) {
      return this.language === 'zh' ? '连接失败' : 'Connection failed'
    }
    return this.language === 'zh' ? '选择' : 'Select'
  }

  private physicalCardErrorText(reason: PhysicalCardFailureReason): string {
    if (reason === PhysicalCardFailureReason.NO_DEVICE) {
      return this.language === 'zh' ? '未发现实体卡' : 'No physical card found'
    }
    if (reason === PhysicalCardFailureReason.DISCOVERY_FAILED) {
      return this.language === 'zh' ? '实体卡发现失败' : 'Discovery failed'
    }
    if (reason === PhysicalCardFailureReason.CONNECTION_FAILED) {
      return this.language === 'zh' ? '无法连接这张实体卡' : 'Unable to connect to this card'
    }
    if (reason === PhysicalCardFailureReason.CONNECTION_INTERRUPTED) {
      return this.language === 'zh' ? '连接过程中断' : 'Connection was interrupted'
    }
    if (reason === PhysicalCardFailureReason.CAPACITY_FULL) {
      return this.language === 'zh' ?
        '主要实体卡容量不足，请删除不需要的凭证或更换实体卡' :
        'The primary card is full. Remove an unused credential or replace the card.'
    }
    if (reason === PhysicalCardFailureReason.ALREADY_WRITTEN) {
      return this.language === 'zh' ?
        '该许可已经写入当前实体卡' :
        'This authorization is already on the card'
    }
    if (reason === PhysicalCardFailureReason.TRANSLATION_FAILED) {
      return this.language === 'zh' ?
        '无法生成实体卡凭证' : 'Unable to translate the credential'
    }
    if (reason === PhysicalCardFailureReason.VERIFICATION_FAILED) {
      return this.language === 'zh' ?
        '写后校验失败，可以重新尝试' :
        'Post-write verification failed. You can retry.'
    }
    if (reason === PhysicalCardFailureReason.PERSISTENCE_FAILED) {
      return this.language === 'zh' ?
        '保存 Mock 写卡结果失败，本次写入已回滚' :
        'Mock persistence failed. This write was rolled back.'
    }
    if (reason === PhysicalCardFailureReason.DEVICE_OFFLINE) {
      return this.language === 'zh' ?
        '实体卡在写入过程中离线' : 'The physical card went offline during writing'
    }
    if (reason === PhysicalCardFailureReason.CANCELLED) {
      return this.language === 'zh' ? '已取消写入' : 'Write cancelled'
    }
    if (reason === PhysicalCardFailureReason.NOT_CONNECTED) {
      return this.language === 'zh' ? '请先连接实体卡' : 'Connect the card first'
    }
    return this.language === 'zh' ?
      '写入失败，可以重新尝试' : 'Write failed. You can retry.'
  }

  private bindingStatusText(): string {
    const status: CredentialBindingStatus =
      this.currentCard().credentialBindingStatus
    if (status === CredentialBindingStatus.WRITTEN) {
      return this.language === 'zh' ? '已写入实体卡' : 'Written to a physical card'
    }
    if (status === CredentialBindingStatus.WRITING ||
      status === CredentialBindingStatus.VERIFYING) {
      return this.language === 'zh' ? '正在写入' : 'Writing'
    }
    if (status === CredentialBindingStatus.WRITE_FAILED) {
      return this.language === 'zh' ? '写入失败' : 'Write failed'
    }
    if (this.currentCard().credentialCondition ===
      CredentialCondition.UPDATE_REQUIRED) {
      return this.language === 'zh' ? '凭证需要更新' : 'Credential update required'
    }
    if (this.currentCard().credentialCondition === CredentialCondition.REMOVED) {
      return this.language === 'zh' ? '凭证已从实体卡删除' : 'Credential removed'
    }
    return this.language === 'zh' ? '尚未写入实体卡' : 'Not written to a physical card'
  }

  private bindingDescription(): string {
    if (this.currentCard().credentialBindingStatus ===
      CredentialBindingStatus.WRITTEN) {
      return this.language === 'zh' ?
        '授权保存在手机端，实体卡仅保存转译后的凭证材料。' :
        'The phone retains the authorization; WS63 stores only translated credential material.'
    }
    return this.language === 'zh' ?
      '授权有效，可选择一张 WS63 实体卡写入凭证。' :
      'The authorization is valid and can be written to a WS63 card.'
  }

  private boundPhysicalCardName(): string {
    const card: PhysicalCard | null =
      this.cardStore.getPhysicalCard(this.currentCard().physicalCardId)
    return card ? card.displayName : '-'
  }

  private boundPhysicalCardIdentifier(): string {
    const card: PhysicalCard | null =
      this.cardStore.getPhysicalCard(this.currentCard().physicalCardId)
    return card ? card.cardAnonId : '****'
  }

  private boundCredential(): Credential | null {
    return this.cardStore.getCredentialForCard(this.currentCard())
  }

  private boundCredentialWrittenAt(): string {
    const credential: Credential | null = this.boundCredential()
    return credential && credential.writtenAt.length > 0 ?
      credential.writtenAt.substring(0, 19) : '-'
  }

  private boundCredentialVersion(): string {
    const credential: Credential | null = this.boundCredential()
    return credential ? `v${credential.credentialVersion}` : '-'
  }

  private boundCredentialVerifiedAt(): string {
    const credential: Credential | null = this.boundCredential()
    return credential && credential.verifiedAt.length > 0 ?
      credential.verifiedAt.substring(0, 19) : '-'
  }

  private currentCardIndex(): number {
    let selectedIndex: number = 0
    this.cardStore.cards.forEach((card: DigitalCard, index: number) => {
      if (card.id === this.selectedCardId) {
        selectedIndex = index
      }
    })
    return selectedIndex
  }

  private usesSplitLayout(): boolean {
    return this.isTablet && this.windowWidth >= 840
  }

  private tabletCardColumnWidth(): number {
    return this.windowWidth >= 1200 ? 420 : 340
  }

  private currentCard(): DigitalCard {
    return this.cardStore.cards[this.currentCardIndex()]
  }

  private maskedCardNumber(): string {
    const number: string = this.currentCard().anonymousNumber.split(' ').join('')
    return `•••• •••• •••• ${number.slice(-4)}`
  }

  private updateNickname(value: string): void {
    this.cardStore.updateNickname(this.currentCard().id, value)
  }

  private updateCategory(value: string): void {
    this.cardStore.updateCategory(this.currentCard().id, value)
  }

  private updateEnabled(isOn: boolean): void {
    this.cardStore.updateEnabled(this.currentCard().id, isOn)
  }

  private updateTwoFactor(isOn: boolean): void {
    this.cardStore.updateUserConfirmation(this.currentCard().id, isOn)
  }
}
