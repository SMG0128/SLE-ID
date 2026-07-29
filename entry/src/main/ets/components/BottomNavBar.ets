import * as Theme from '../common/Theme'

@Component
export struct BottomNavBar {
  @Link currentIndex: number
  @Link language: string
  @Link showScanPage: boolean

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // The center dome and the bar share one glass material so Scan reads as a tab extension.
      Circle()
        .width(72)
        .height(72)
        .fill('rgba(248, 249, 250, 0.92)')
        .backdropBlur(40)
        .borderWidth(1)
        .borderColor('rgba(255, 255, 255, 0.72)')
        .shadow({
          radius: 18,
          color: 'rgba(30, 34, 78, 0.08)',
          offsetY: 3
        })
        .position({ x: '50%', y: 0 })
        .translate({ x: -36 })

      Row()
        .width('100%')
        .height(64)
        .backgroundColor('rgba(248, 249, 250, 0.86)')
        .backdropBlur(40)
        .borderRadius(Theme.RADIUS_FULL)
        .borderWidth(1)
        .borderColor('rgba(255, 255, 255, 0.72)')
        .shadow({
          radius: 20,
          color: 'rgba(30, 34, 78, 0.08)',
          offsetY: 5
        })
        .position({ x: 0, y: 14 })

      Row() {
        this.StandardTab(
          0,
          $r('sys.symbol.creditcard'),
          this.language === 'zh' ? '卡片' : 'Cards'
        )

        this.ScanTab()

        this.StandardTab(
          1,
          $r('sys.symbol.person'),
          this.language === 'zh' ? '我的' : 'Profile'
        )
      }
      .width('100%')
      .height(78)
      .padding({ left: 6, right: 6, bottom: 6 })
      .alignItems(VerticalAlign.Bottom)
    }
    .width('calc(100% - 40px)')
    .height(78)
    .position({ bottom: Theme.NAV_BAR_BOTTOM_MARGIN })
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  StandardTab(index: number, icon: Resource, label: string) {
    Column({ space: 2 }) {
      SymbolGlyph(icon)
        .fontSize(Theme.ICON_LG)
        .fontColor([this.isTabSelected(index) ? Theme.PRIMARY : Theme.ON_SURFACE_VARIANT])

      Text(label)
        .fontSize(Theme.LABEL_MD_FONT_SIZE)
        .fontWeight(this.isTabSelected(index) ?
          Theme.FONT_WEIGHT_SEMIBOLD : Theme.FONT_WEIGHT_MEDIUM)
        .fontColor(this.isTabSelected(index) ? Theme.PRIMARY : Theme.ON_SURFACE_VARIANT)
    }
    .layoutWeight(1)
    .height(50)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(Theme.RADIUS_FULL)
    .backgroundColor(this.isTabSelected(index) ? 'rgba(70, 72, 212, 0.11)' : 'transparent')
    .animation({
      duration: Theme.ANIMATION_DURATION,
      curve: Curve.EaseInOut
    })
    .onClick(() => {
      this.currentIndex = index
      this.showScanPage = false
    })
  }

  @Builder
  ScanTab() {
    Column({ space: 2 }) {
      Stack() {
        Circle()
          .width(42)
          .height(42)
          .fill(this.showScanPage ? 'rgba(70, 72, 212, 0.11)' : 'rgba(255, 255, 255, 0.6)')

        SymbolGlyph($r('sys.symbol.camera'))
          .fontSize(Theme.ICON_LG)
          .fontColor([Theme.PRIMARY])
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .borderWidth(1)
      .borderColor(this.showScanPage ?
        'rgba(70, 72, 212, 0.18)' : 'rgba(255, 255, 255, 0.72)')
      .clip(true)
      .alignContent(Alignment.Center)

      Text(this.language === 'zh' ? '扫描' : 'Scan')
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.PRIMARY)
    }
    .width(72)
    .height(72)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .scale({
      x: this.showScanPage ? 1.03 : 1,
      y: this.showScanPage ? 1.03 : 1
    })
    .animation({
      duration: Theme.ANIMATION_DURATION,
      curve: Curve.EaseInOut
    })
    .onClick(() => {
      this.showScanPage = true
    })
  }

  private isTabSelected(index: number): boolean {
    return !this.showScanPage && this.currentIndex === index
  }
}
