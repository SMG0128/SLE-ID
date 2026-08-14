import * as Theme from '../common/Theme'

@Component
export struct SideNavBar {
  @Link currentIndex: number
  @Link language: string
  @Link showAddCardModal: boolean
  @Link showPhysicalCardManagerPage: boolean
  @Link showScanPage: boolean

  build() {
    Column() {
      // Brand header
      Column() {
        Row({ space: Theme.SPACING_SM }) {
          SymbolGlyph($r('sys.symbol.creditcard'))
            .fontSize(Theme.ICON_XL)
            .fontColor([Theme.PRIMARY])

          Text('SleKey')
            .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_BOLD)
            .fontColor(Theme.PRIMARY)
        }
        .alignItems(VerticalAlign.Center)

        Text(this.language === 'zh' ? '近场身份识别' : 'Near-field Identification')
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .margin({ top: Theme.SPACING_XS })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: Theme.SPACING_LG,
        right: Theme.SPACING_LG,
        top: Theme.STATUS_BAR_PADDING + Theme.SPACING_MD,
        bottom: Theme.SPACING_MD
      })

      // Wallet shortcuts
      Row({ space: Theme.SPACING_XS }) {
        this.ShortcutButton(
          $r('sys.symbol.creditcard'),
          this.language === 'zh' ? '实体卡' : 'Physical card',
          'physicalCard'
        )

        this.ShortcutButton(
          $r('sys.symbol.plus'),
          this.language === 'zh' ? '添加卡片' : 'Add card',
          'addCard'
        )
      }
      .width('100%')
      .padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM, bottom: Theme.SPACING_LG })

      // Navigation items
      Column() {
        this.NavItem(
          0,
          $r('sys.symbol.creditcard'),
          this.language === 'zh' ? '卡片' : 'Cards'
        )

        this.NavItem(
          1,
          $r('sys.symbol.person'),
          this.language === 'zh' ? '我的' : 'Profile'
        )
      }
      .width('100%')
      .padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM })
      .layoutWeight(1)

      this.TemporaryConnectionButton()

      // Version info
      Text(this.language === 'zh' ? '版本 4.12.0' : 'Version 4.12.0')
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontColor(Theme.OUTLINE_VARIANT)
        .margin({ bottom: Theme.SPACING_LG })
    }
    .width(Theme.TABLET_SIDE_NAV_WIDTH)
    .height('100%')
    .backgroundColor('rgba(248, 249, 250, 0.85)')
    .backdropBlur(40)
    .borderWidth({ right: 1 })
    .borderColor('rgba(255, 255, 255, 0.3)')
  }

  @Builder
  NavItem(index: number, icon: Resource, label: string) {
    Row({ space: Theme.SPACING_SM }) {
      SymbolGlyph(icon)
        .fontSize(Theme.ICON_LG)
        .fontColor([this.currentIndex === index ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT])
        .animation({
          duration: Theme.ANIMATION_DURATION,
          curve: Curve.EaseInOut
        })

      Text(label)
        .fontSize(Theme.BODY_MD_FONT_SIZE)
        .fontWeight(this.currentIndex === index ? Theme.FONT_WEIGHT_SEMIBOLD : Theme.FONT_WEIGHT_MEDIUM)
        .fontColor(this.currentIndex === index ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT)
        .animation({
          duration: Theme.ANIMATION_DURATION,
          curve: Curve.EaseInOut
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: Theme.SPACING_MD, right: Theme.SPACING_MD })
    .borderRadius(Theme.RADIUS_DEFAULT)
    .backgroundColor(this.currentIndex === index ? Theme.PRIMARY : 'transparent')
    .animation({
      duration: Theme.ANIMATION_DURATION,
      curve: Curve.EaseInOut
    })
    .margin({ bottom: Theme.SPACING_XS })
    .onClick(() => {
      this.currentIndex = index
      this.showScanPage = false
    })
  }

  @Builder
  TemporaryConnectionButton() {
    Row({ space: Theme.SPACING_SM }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(42)
          .height(42)
          .fill(this.showScanPage ? 'rgba(70, 72, 212, 0.17)' : 'rgba(70, 72, 212, 0.08)')

        SymbolGlyph($r('sys.symbol.camera'))
          .fontSize(Theme.ICON_LG)
          .fontColor([Theme.PRIMARY])
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor(this.showScanPage ?
        'rgba(70, 72, 212, 0.28)' : 'rgba(255, 255, 255, 0.58)')
      .clip(true)

      Column({ space: 2 }) {
        Text(this.language === 'zh' ? '临时连接' : 'Temporary connection')
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(this.showScanPage ? Theme.PRIMARY : Theme.ON_SURFACE)
          .maxLines(1)

        Text(this.language === 'zh' ? '扫描附近设备' : 'Scan nearby devices')
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width(Theme.TABLET_SIDE_NAV_WIDTH - Theme.SPACING_MD)
    .height(64)
    .padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM })
    .margin({ left: Theme.SPACING_SM, right: Theme.SPACING_SM, bottom: Theme.SPACING_MD })
    .backgroundColor(this.showScanPage ?
      'rgba(238, 240, 255, 0.92)' : 'rgba(255, 255, 255, 0.64)')
    .backdropBlur(24)
    .borderRadius(Theme.RADIUS_DEFAULT)
    .borderWidth(1)
    .borderColor(this.showScanPage ?
      'rgba(70, 72, 212, 0.18)' : 'rgba(255, 255, 255, 0.72)')
    .shadow({
      radius: this.showScanPage ? 16 : 8,
      color: this.showScanPage ? 'rgba(70, 72, 212, 0.12)' : 'rgba(30, 34, 78, 0.04)',
      offsetY: 3
    })
    .onClick(() => {
      this.showScanPage = !this.showScanPage
    })
  }

  @Builder
  ShortcutButton(icon: Resource, label: string, action: string) {
    Column({ space: Theme.SPACING_XS }) {
      SymbolGlyph(icon)
        .fontSize(Theme.ICON_LG)
        .fontColor([Theme.PRIMARY])

      Text(label)
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_MEDIUM)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(255, 255, 255, 0.64)')
    .backdropBlur(20)
    .borderRadius(Theme.RADIUS_DEFAULT)
    .borderWidth(1)
    .borderColor('rgba(255, 255, 255, 0.72)')
    .onClick(() => {
      this.showScanPage = false
      if (action === 'physicalCard') {
        this.showPhysicalCardManagerPage = true
        return
      }
      this.showAddCardModal = true
    })
  }
}
