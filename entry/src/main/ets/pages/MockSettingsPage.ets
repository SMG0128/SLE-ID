import * as Theme from '../common/Theme'

@Component
export struct MockSettingsPage {
  @Link language: string
  @Link showMockSettingsPage: boolean
  @Link showVerificationDialog: boolean

  build() {
    Column() {
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
          this.showMockSettingsPage = false
        })

        Text(this.language === 'zh' ? 'MOCK 测试' : 'MOCK Testing')
          .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE)
          .margin({ left: Theme.SPACING_MD })

        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN })
      .backgroundColor('rgba(248, 249, 250, 0.8)')
      .backdropBlur(40)
      .borderWidth({ bottom: 1 })
      .borderColor('rgba(199, 196, 215, 0.3)')

      Column() {
        Text(this.language === 'zh' ? '开发测试入口' : 'DEVELOPER TESTS')
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
          .alignSelf(ItemAlign.Start)
          .margin({ left: Theme.SPACING_SM, bottom: Theme.SPACING_XS })

        Row() {
          Stack() {
            SymbolGlyph($r('sys.symbol.shield_checkered'))
              .fontSize(Theme.ICON_LG)
              .fontColor([Theme.ON_PRIMARY])
          }
          .width(44)
          .height(44)
          .borderRadius(Theme.RADIUS_FULL)
          .backgroundColor(Theme.PRIMARY)

          Column() {
            Text(this.language === 'zh' ? '* 二次验证弹窗' : '* Secondary Verification')
              .fontSize(Theme.BODY_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_MEDIUM)
              .fontColor(Theme.ON_SURFACE)

            Text(this.language === 'zh' ? '模拟收到 SLE 验证请求' : 'Simulate an incoming SLE verification request')
              .fontSize(Theme.LABEL_SM_FONT_SIZE)
              .fontColor(Theme.ON_SURFACE_VARIANT)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: Theme.SPACING_MD })

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(Theme.ICON_MD)
            .fontColor([Theme.OUTLINE_VARIANT])
        }
        .width('100%')
        .padding(Theme.SPACING_LG)
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.82)')
        .borderRadius(Theme.RADIUS_LG)
        .borderWidth(1)
        .borderColor('rgba(255, 255, 255, 0.6)')
        .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 })
        .onClick(() => {
          this.showVerificationDialog = true
        })
      }
      .width('100%')
      .padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN })
      .margin({ top: Theme.SPACING_XL })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BACKGROUND)
    .padding({ top: Theme.STATUS_BAR_PADDING })
  }
}
