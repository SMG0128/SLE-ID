import * as Theme from '../common/Theme'

@Component
export struct BottomNavBar {
  @Link currentIndex: number
  @Link language: string

  build() {
    Row() {
      // Cards tab
      Column() {
        SymbolGlyph($r('sys.symbol.creditcard'))
          .fontSize(Theme.ICON_LG)
          .fontColor([this.currentIndex === 0 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT])
          .animation({
            duration: Theme.ANIMATION_DURATION,
            curve: Curve.EaseInOut
          })

        Text(this.language === 'zh' ? '卡片' : 'Cards')
          .fontSize(Theme.LABEL_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_MEDIUM)
          .fontColor(this.currentIndex === 0 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT)
          .margin({ top: 2 })
          .animation({
            duration: Theme.ANIMATION_DURATION,
            curve: Curve.EaseInOut
          })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .height(48)
      .borderRadius(Theme.RADIUS_FULL)
      .backgroundColor(this.currentIndex === 0 ? Theme.PRIMARY : 'transparent')
      .animation({
        duration: Theme.ANIMATION_DURATION,
        curve: Curve.EaseInOut
      })
      .onClick(() => {
        this.currentIndex = 0
      })

      // Profile tab
      Column() {
        SymbolGlyph($r('sys.symbol.person'))
          .fontSize(Theme.ICON_LG)
          .fontColor([this.currentIndex === 1 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT])
          .animation({
            duration: Theme.ANIMATION_DURATION,
            curve: Curve.EaseInOut
          })

        Text(this.language === 'zh' ? '我的' : 'Profile')
          .fontSize(Theme.LABEL_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_MEDIUM)
          .fontColor(this.currentIndex === 1 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT)
          .margin({ top: 2 })
          .animation({
            duration: Theme.ANIMATION_DURATION,
            curve: Curve.EaseInOut
          })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .height(48)
      .borderRadius(Theme.RADIUS_FULL)
      .backgroundColor(this.currentIndex === 1 ? Theme.PRIMARY : 'transparent')
      .animation({
        duration: Theme.ANIMATION_DURATION,
        curve: Curve.EaseInOut
      })
      .onClick(() => {
        this.currentIndex = 1
      })
    }
    .width('calc(100% - 40px)')
    .height(64)
    .padding(6)
    .backgroundColor('rgba(248, 249, 250, 0.8)')
    .backdropBlur(40)
    .borderRadius(Theme.RADIUS_FULL)
    .borderWidth(1)
    .borderColor('rgba(255, 255, 255, 0.2)')
    .shadow({
      radius: 20,
      color: 'rgba(0, 0, 0, 0.06)',
      offsetY: 4
    })
    .position({
      bottom: Theme.NAV_BAR_BOTTOM_MARGIN
    })
    .alignSelf(ItemAlign.Center)
  }
}
