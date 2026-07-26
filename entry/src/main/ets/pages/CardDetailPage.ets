import * as Theme from '../common/Theme'
import { CardModel } from '../common/CardModel'

@Component
export struct CardDetailPage {
  @Link cards: CardModel[]
  @Link language: string
  @Link showCardDetailPage: boolean
  @Link selectedCardId: string

  build() {
    Column() {
      // Top App Bar
      this.TopAppBar()

      // Scrollable content
      Scroll() {
        Column() {
          // Card visualization
          this.CardVisualization()

          // Information section
          this.InformationSection()

          // Editable card settings
          this.CardSettingsSection()

          // Security section
          this.SecuritySection()

          // Danger zone
          this.DangerZone()
        }
        .width('100%')
        .padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN, bottom: 40 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.SURFACE)
    .padding({ top: Theme.STATUS_BAR_PADDING })
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

          Toggle({ type: ToggleType.Switch, isOn: this.currentCard().enabled })
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

            Text(this.language === 'zh' ? '需要二次验证' : 'Secondary validation required')
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
              .fontColor(Theme.ON_SURFACE_VARIANT)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: Theme.SPACING_MD })
        }

        Blank()

        Toggle({ type: ToggleType.Switch, isOn: this.currentCard().twoFactorEnabled })
          .selectedColor(Theme.PRIMARY)
          .switchPointColor(Color.White)
          .width(44)
          .height(24)
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

  private currentCardIndex(): number {
    let selectedIndex: number = 0
    this.cards.forEach((card: CardModel, index: number) => {
      if (card.id === this.selectedCardId) {
        selectedIndex = index
      }
    })
    return selectedIndex
  }

  private currentCard(): CardModel {
    return this.cards[this.currentCardIndex()]
  }

  private maskedCardNumber(): string {
    const number: string = this.currentCard().cardNumber.split(' ').join('')
    return `•••• •••• •••• ${number.slice(-4)}`
  }

  private updateNickname(value: string): void {
    this.cards[this.currentCardIndex()].nickname = value
    this.cards = this.cards.slice()
  }

  private updateCategory(value: string): void {
    this.cards[this.currentCardIndex()].category = value
    this.cards = this.cards.slice()
  }

  private updateEnabled(isOn: boolean): void {
    this.cards[this.currentCardIndex()].enabled = isOn
    this.cards = this.cards.slice()
  }

  private updateTwoFactor(isOn: boolean): void {
    this.cards[this.currentCardIndex()].twoFactorEnabled = isOn
    this.cards = this.cards.slice()
  }
}
