import * as Theme from '../common/Theme'

@Component
export struct LanguagePage {
  @Link language: string
  @Link showLanguagePage: boolean

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
          this.showLanguagePage = false
        })

        Text(this.language === 'zh' ? '语言' : 'Language')
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
        Text(this.language === 'zh' ? '选择语言' : 'Choose a language')
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
          .alignSelf(ItemAlign.Start)
          .margin({ left: Theme.SPACING_SM, bottom: Theme.SPACING_XS })

        Column() {
          this.LanguageOption('zh', '中文', '简体中文')
          Divider()
            .color('rgba(199, 196, 215, 0.1)')
            .margin({ left: Theme.SPACING_LG, right: Theme.SPACING_LG })
          this.LanguageOption('en', 'English', 'English')
        }
        .width('100%')
        .backgroundColor('rgba(255, 255, 255, 0.8)')
        .borderRadius(Theme.RADIUS_LG)
        .clip(true)
        .borderWidth(1)
        .borderColor('rgba(255, 255, 255, 0.5)')
        .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 })
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

  @Builder
  LanguageOption(value: string, title: string, subtitle: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_REGULAR)
          .fontColor(Theme.ON_SURFACE)
        Text(subtitle)
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.language === value) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(Theme.ICON_LG)
          .fontColor([Theme.PRIMARY])
      }
    }
    .width('100%')
    .padding({ left: Theme.SPACING_LG, right: Theme.SPACING_LG, top: Theme.SPACING_MD, bottom: Theme.SPACING_MD })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.language = value
    })
  }
}
