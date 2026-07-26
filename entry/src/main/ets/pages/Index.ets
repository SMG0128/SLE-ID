import { BottomNavBar } from '../components/BottomNavBar'
import { CardsPage } from './CardsPage'
import { CardDetailPage } from './CardDetailPage'
import { ProfilePage } from './ProfilePage'
import { LanguagePage } from './LanguagePage'
import { MockSettingsPage } from './MockSettingsPage'
import { CardModel } from '../common/CardModel'
import { CardPreview } from '../components/CardPreview'
import * as Theme from '../common/Theme'

@Entry
@Component
struct Index {
  @State currentIndex: number = 0
  @State showAddCardModal: boolean = false
  @State language: string = 'zh'
  @State showLanguagePage: boolean = false
  @State showCardDetailPage: boolean = false
  @State showMockSettingsPage: boolean = false
  @State showVerificationDialog: boolean = false
  @State slideProgress: number = 0
  @StorageLink('verificationPending') verificationPending: boolean = false
  @StorageLink('verificationCardId') verificationCardId: string = '2'
  @State selectedCardId: string = '2'
  @State cards: CardModel[] = [
    {
      id: '1',
      name: 'Identity Card',
      issuer: 'SleKey Identity Services',
      cardNumber: '8820 1104 7312',
      twoFactorEnabled: true,
      nickname: 'My Identity',
      detail: 'Digital identification',
      category: 'Identity',
      enabled: true,
      icon: $r('sys.symbol.lock_shield'),
      accentColor: Theme.PRIMARY
    },
    {
      id: '2',
      name: 'MTR Ticket',
      issuer: 'Hong Kong Transport',
      cardNumber: '0021 4521 4422',
      twoFactorEnabled: true,
      nickname: 'Metro',
      detail: 'Ticket pass for MTR',
      category: 'Traffic',
      enabled: true,
      icon: $r('sys.symbol.creditcard'),
      accentColor: Theme.SECONDARY
    },
    {
      id: '3',
      name: 'Access Key',
      issuer: 'SleKey Workplace',
      cardNumber: '4108 7621 0096',
      twoFactorEnabled: false,
      nickname: 'Office',
      detail: 'Smart office entry',
      category: 'Access',
      enabled: true,
      icon: $r('sys.symbol.key'),
      accentColor: Theme.TERTIARY
    }
  ]

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Main content area
      if (this.showCardDetailPage) {
        CardDetailPage({
          cards: $cards,
          language: $language,
          showCardDetailPage: $showCardDetailPage,
          selectedCardId: $selectedCardId
        })
      } else if (this.showLanguagePage) {
        LanguagePage({ language: $language, showLanguagePage: $showLanguagePage })
      } else if (this.showMockSettingsPage) {
        MockSettingsPage({
          language: $language,
          showMockSettingsPage: $showMockSettingsPage,
          showVerificationDialog: $showVerificationDialog
        })
      } else if (this.currentIndex === 0) {
        CardsPage({
          showAddCardModal: $showAddCardModal,
          language: $language,
          cards: $cards,
          showCardDetailPage: $showCardDetailPage,
          selectedCardId: $selectedCardId,
          showMockSettingsPage: $showMockSettingsPage
        })
      } else {
        ProfilePage({ language: $language, showLanguagePage: $showLanguagePage })
      }

      // Add Card Modal
      if (this.showAddCardModal) {
        this.AddCardModal()
      }

      // Bottom Navigation Bar
      if (!this.showLanguagePage && !this.showCardDetailPage && !this.showMockSettingsPage) {
        BottomNavBar({ currentIndex: $currentIndex, language: $language })
      }

      // SLE verification request overlay
      if (this.showVerificationDialog || this.verificationPending) {
        this.VerificationDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BACKGROUND)
  }

  @Builder
  VerificationDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(25, 28, 29, 0.46)')
        .backdropBlur(12)

      Column() {
        Text(this.language === 'zh' ? '二次验证' : 'Secondary Verification')
          .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_BOLD)
          .fontColor(Theme.ON_SURFACE)
          .textAlign(TextAlign.Center)
          .width('100%')

        Text(this.language === 'zh' ? '请核对卡片信息，并滑动确认本次连接。' :
          'Review the card information, then slide to approve this connection.')
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: Theme.SPACING_XS, bottom: Theme.SPACING_LG })

        CardPreview({ card: this.verificationCard(), language: this.language })
          .width('100%')

        Stack({ alignContent: Alignment.Center }) {
          Text(this.language === 'zh' ? '滑动以同意  →' : 'Slide to approve  →')
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(this.slideProgress > 54 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT)

          Slider({
            value: this.slideProgress,
            min: 0,
            max: 100,
            step: 1,
            style: SliderStyle.InSet,
            direction: Axis.Horizontal,
            reverse: false
          })
            .width('100%')
            .height(56)
            .selectedColor(Theme.PRIMARY)
            .trackColor(Theme.SURFACE_CONTAINER_HIGH)
            .blockColor(Color.White)
            .trackThickness(52)
            .blockSize({ width: 44, height: 44 })
            .onChange((value: number) => {
              this.slideProgress = value
              if (value >= 98) {
                this.approveVerification()
              }
            })
        }
        .width('100%')
        .height(56)
        .margin({ top: Theme.SPACING_LG })
      }
      .width('90%')
      .constraintSize({ maxWidth: 460 })
      .padding(Theme.SPACING_LG)
      .backgroundColor('rgba(248, 249, 250, 0.94)')
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

  private verificationCard(): CardModel {
    let result: CardModel = this.cards[0]
    this.cards.forEach((card: CardModel) => {
      if (card.id === this.verificationCardId) {
        result = card
      }
    })
    return result
  }

  private approveVerification(): void {
    this.verificationPending = false
    this.showVerificationDialog = false
    this.slideProgress = 0
    try {
      this.getUIContext().getPromptAction().showToast({
        message: this.language === 'zh' ? '已同意二次验证' : 'Verification approved'
      })
    } catch (error) {
      console.error(`Unable to show verification result: ${JSON.stringify(error)}`)
    }
  }

  @Builder
  AddCardModal() {
    Stack() {
      // Backdrop
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.4)')
        .onClick(() => {
          this.showAddCardModal = false
        })

      // Modal content
      Column() {
        // Header
        Column() {
          Text(this.language === 'zh' ? '添加卡片' : 'Add Card')
            .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_BOLD)
            .fontColor(Theme.ON_SURFACE)
            .textAlign(TextAlign.Center)

          Text(this.language === 'zh' ? '输入卡片信息以完成关联' : 'Enter card information to link it')
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .opacity(0.7)
            .textAlign(TextAlign.Center)
            .margin({ top: Theme.SPACING_XS })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        // Input section
        Column() {
          Stack({ alignContent: Alignment.End }) {
            TextInput({ placeholder: this.language === 'zh' ? '请输入卡片代号' : 'Enter card code' })
              .width('100%')
              .height(56)
              .fontSize(Theme.BODY_LG_FONT_SIZE)
              .fontColor(Theme.ON_SURFACE)
              .backgroundColor(Theme.SURFACE_CONTAINER_LOW)
              .borderRadius(Theme.RADIUS_DEFAULT)
              .padding({ left: Theme.SPACING_MD, right: Theme.SPACING_MD + Theme.ICON_MD + Theme.SPACING_XS })
              .placeholderColor('rgba(70, 69, 84, 0.4)')

            SymbolGlyph($r('sys.symbol.creditcard'))
              .fontSize(Theme.ICON_MD)
              .fontColor([Theme.ON_SURFACE_VARIANT])
              .margin({ right: Theme.SPACING_MD })
          }
          .width('100%')

          Row() {
            SymbolGlyph($r('sys.symbol.questionmark_circle'))
              .fontSize(Theme.ICON_SM)
              .fontColor(['rgba(70, 69, 84, 0.6)'])

            Text(this.language === 'zh' ? '代号通常位于卡片背面' : 'The code is usually on the back of the card')
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontColor('rgba(70, 69, 84, 0.6)')
              .margin({ left: Theme.SPACING_XS })
          }
          .width('100%')
          .margin({ top: Theme.SPACING_XS })
          .padding({ left: Theme.SPACING_BASE })
        }
        .width('100%')
        .margin({ top: Theme.SPACING_XL })

        // Action buttons
        Row() {
          Button(this.language === 'zh' ? '取消' : 'Cancel')
            .flexGrow(1)
            .height(48)
            .fontSize(Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .backgroundColor(Theme.SURFACE_CONTAINER_HIGH)
            .borderRadius(Theme.RADIUS_DEFAULT)
            .borderWidth(1)
            .borderColor('rgba(199, 196, 215, 0.3)')
            .onClick(() => {
              this.showAddCardModal = false
            })

          Button(this.language === 'zh' ? '确认' : 'Confirm')
            .flexGrow(1)
            .height(48)
            .fontSize(Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_PRIMARY)
            .backgroundColor(Theme.PRIMARY)
            .borderRadius(Theme.RADIUS_DEFAULT)
            .shadow({
              radius: 16,
              color: 'rgba(70, 72, 212, 0.3)',
              offsetY: 4
            })
            .margin({ left: Theme.SPACING_MD })
            .onClick(() => {
              this.showAddCardModal = false
            })
        }
        .width('100%')
        .margin({ top: Theme.SPACING_XL })
      }
      .width('90%')
      .padding(Theme.SPACING_XL)
      .backgroundColor(Theme.SURFACE)
      .borderRadius(Theme.RADIUS_MD)
      .shadow({
        radius: 40,
        color: 'rgba(0, 0, 0, 0.08)',
        offsetY: 12
      })
      .position({ x: '50%', y: '50%' })
      .translate({ x: '-50%', y: '-50%' })
    }
    .width('100%')
    .height('100%')
  }
}
