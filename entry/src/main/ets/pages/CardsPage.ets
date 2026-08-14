import * as Theme from '../common/Theme'
import { DigitalCard } from '../models/DigitalCard'
import { CardStore } from '../stores/CardStore'
import { CardPreview } from '../components/CardPreview'

@Component
export struct CardsPage {
  @Link showAddCardModal: boolean
  @Link language: string
  @ObjectLink cardStore: CardStore
  @Link showCardDetailPage: boolean
  @Link selectedCardId: string
  @Link showMockSettingsPage: boolean
  @Link showPhysicalCardManagerPage: boolean
  @Prop isTablet: boolean = false

  build() {
    Column() {
      // Phone keeps the top app bar; tablet actions live in the side navigation.
      if (!this.isTablet) {
        this.TopAppBar()
      }

      // Scrollable content
      Scroll() {
        Column() {
          // Section header
          Row() {
            Column() {
              Text(this.language === 'zh' ? '卡片管理' : 'Card Management')
                .fontSize(Theme.LABEL_MD_FONT_SIZE)
                .fontWeight(Theme.FONT_WEIGHT_MEDIUM)
                .fontColor(Theme.ON_SURFACE_VARIANT)
                .margin({ bottom: Theme.SPACING_XS })

              Text(this.language === 'zh' ? '我的卡片' : 'My Cards')
                .fontSize(this.isTablet ? Theme.HEADLINE_LG_FONT_SIZE : Theme.HEADLINE_LG_MOBILE_FONT_SIZE)
                .fontWeight(Theme.FONT_WEIGHT_BOLD)
                .fontColor(Theme.ON_SURFACE)
            }
            .alignItems(HorizontalAlign.Start)

            Row() {
              Text(this.activeCountText())
                .fontSize(Theme.LABEL_MD_FONT_SIZE)
                .fontWeight(Theme.FONT_WEIGHT_MEDIUM)
                .fontColor(Theme.PRIMARY)
            }
            .padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM, top: Theme.SPACING_XS, bottom: Theme.SPACING_XS })
            .backgroundColor('rgba(70, 72, 212, 0.1)')
            .borderRadius(Theme.RADIUS_FULL)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Bottom)
          .margin({ bottom: Theme.SPACING_LG })

          if (this.cardStore.isLoading) {
            Text(this.language === 'zh' ? '正在同步卡片…' : 'Syncing cards…')
              .fontSize(Theme.LABEL_MD_FONT_SIZE)
              .fontColor(Theme.ON_SURFACE_VARIANT)
              .margin({ bottom: Theme.SPACING_MD })
          } else if (this.cardStore.isOffline) {
            Text(this.language === 'zh' ?
              '当前离线，正在显示本地缓存' :
              'Offline — showing cached cards')
              .fontSize(Theme.LABEL_MD_FONT_SIZE)
              .fontColor(Theme.ERROR)
              .margin({ bottom: Theme.SPACING_MD })
          } else if (this.cardStore.errorMessage.length > 0) {
            Text(this.cardStore.errorMessage)
              .fontSize(Theme.LABEL_MD_FONT_SIZE)
              .fontColor(Theme.ERROR)
              .margin({ bottom: Theme.SPACING_MD })
          }

          // Cards list
          if (this.isTablet) {
            // Tablet: multi-column grid
            GridRow({ columns: { sm: 2, md: 2, lg: 3 }, gutter: Theme.TABLET_CARD_GAP }) {
              ForEach(this.cardStore.cards, (card: DigitalCard) => {
                GridCol() {
                  this.CardItem(card)
                }
              }, (card: DigitalCard) => card.id)
            }
            .width('100%')
          } else {
            // Phone: single column
            ForEach(this.cardStore.cards, (card: DigitalCard) => {
              this.CardItem(card)
            }, (card: DigitalCard) => card.id)
          }

          // Security banner
          this.SecurityBanner()
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: this.isTablet ? Theme.TABLET_CONTAINER_MARGIN : Theme.CONTAINER_MARGIN,
          right: this.isTablet ? Theme.TABLET_CONTAINER_MARGIN : Theme.CONTAINER_MARGIN,
          bottom: this.isTablet ? Theme.SPACING_XL : 120
        })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .alignSelf(ItemAlign.Start)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({ top: Theme.STATUS_BAR_PADDING })
  }

  @Builder
  TopAppBar() {
    Row() {
      if (!this.isTablet) {
        SymbolGlyph($r('sys.symbol.paintpalette'))
          .fontSize(Theme.ICON_XL)
          .fontColor([Theme.PRIMARY])

        Text(this.language === 'zh' ? '卡包' : 'Wallet')
          .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_BOLD)
          .fontColor(Theme.PRIMARY)
          .margin({ left: Theme.SPACING_SM })
      } else {
        Text(this.language === 'zh' ? '我的卡片' : 'My Cards')
          .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_BOLD)
          .fontColor(Theme.ON_SURFACE)
      }

      Blank()

      SymbolGlyph($r('sys.symbol.creditcard'))
        .fontSize(Theme.ICON_XL)
        .fontColor([Theme.PRIMARY])
        .margin({ right: Theme.SPACING_LG })
        .onClick(() => {
          this.showPhysicalCardManagerPage = true
        })

      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(Theme.ICON_XL)
        .fontColor([Theme.PRIMARY])
        .onClick(() => {
          this.showAddCardModal = true
        })
    }
    .width('100%')
    .height(56)
    .padding({
      left: this.isTablet ? Theme.TABLET_CONTAINER_MARGIN : Theme.CONTAINER_MARGIN,
      right: this.isTablet ? Theme.TABLET_CONTAINER_MARGIN : Theme.CONTAINER_MARGIN
    })
    .backgroundColor(this.isTablet ? 'rgba(255, 255, 255, 0.58)' : 'rgba(255, 255, 255, 0.7)')
    .backdropBlur(this.isTablet ? 24 : 40)
    .borderWidth({ bottom: 1 })
    .borderColor('rgba(199, 196, 215, 0.1)')
  }

  @Builder
  CardItem(card: DigitalCard) {
    CardPreview({ card: card, language: this.language, isTablet: this.isTablet })
    .width('100%')
    .margin({ bottom: this.isTablet ? 0 : Theme.CARD_GAP })
    .onClick(() => {
      this.selectedCardId = card.id
      this.showCardDetailPage = true
    })
    .scale({ x: this.selectedCardId === card.id ? 0.97 : 1, y: this.selectedCardId === card.id ? 0.97 : 1 })
    .animation({
      duration: Theme.ANIMATION_FAST_DURATION,
      curve: Curve.EaseInOut
    })
  }

  @Builder
  SecurityBanner() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['rgba(0, 0, 0, 0.6)', 0], ['transparent', 1]]
        })
        .zIndex(10)

      Column() {
        Text(this.language === 'zh' ? '安全至上' : 'Security First')
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor('rgba(255, 255, 255, 0.8)')
          .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
          .textCase(TextCase.Normal)

        Text(this.language === 'zh' ? '端到端加密保护' : 'Protected by end-to-end encryption')
          .fontSize(Theme.TITLE_LG_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Color.White)
          .margin({ top: Theme.SPACING_XS })
      }
      .alignItems(HorizontalAlign.Start)
      .padding(Theme.SPACING_MD)
      .zIndex(20)
      .alignSelf(ItemAlign.Start)
    }
    .width('100%')
    .height(this.isTablet ? 140 : 160)
    .borderRadius(Theme.RADIUS_DEFAULT)
    .shadow({
      radius: 40,
      color: 'rgba(0, 0, 0, 0.2)',
      offsetY: 8
    })
    .clip(true)
    .margin({ top: Theme.SPACING_XL })
    .backgroundImage($r('app.media.layered_image'))
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .onClick(() => {
      this.showMockSettingsPage = true
    })
  }

  private activeCountText(): string {
    let count: number = 0
    this.cardStore.cards.forEach((card: DigitalCard) => {
      if (this.cardStore.isCardEnabled(card)) {
        count++
      }
    })
    return this.language === 'zh' ? `${count} 张已启用` : `${count} Enabled`
  }
}
