import * as Theme from '../common/Theme'
import { CardModel } from '../common/CardModel'

@Component
export struct CardPreview {
  @Prop card: CardModel
  @Prop language: string

  build() {
    Column() {
      Stack() {
        Circle()
          .width(192)
          .height(192)
          .fill(this.card.accentColor)
          .opacity(0.05)
      }
      .width('100%')
      .alignContent(Alignment.TopEnd)
      .position({ x: 0, y: 0 })
      .offset({ x: 48, y: -48 })

      Column() {
        Row({ space: 4 }) {
          Stack() {
            SymbolGlyph(this.card.icon)
              .fontSize(Theme.ICON_LG)
              .fontColor([Theme.ON_PRIMARY])
          }
          .width(48)
          .height(48)
          .borderRadius(Theme.RADIUS_FULL)
          .backgroundColor(this.card.accentColor)
          .shadow({ radius: 16, color: this.card.accentColor, offsetY: 4 })

          Blank()

          Text(this.card.enabled ? (this.language === 'zh' ? '已启用' : 'Enabled') :
            (this.language === 'zh' ? '未启用' : 'Disabled'))
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(this.card.enabled ? this.card.accentColor : Theme.ON_SURFACE_VARIANT)
            .padding({ left: Theme.SPACING_MD, right: Theme.SPACING_MD, top: 4, bottom: 4 })
            .backgroundColor(this.card.enabled ? `${this.card.accentColor}1A` : Theme.SURFACE_CONTAINER_HIGH)
            .borderRadius(Theme.RADIUS_FULL)
        }
        .width('100%')
        .margin({ bottom: Theme.SPACING_XL })

        Column() {
          Text(this.card.nickname.length > 0 ? this.card.nickname : this.card.name)
            .fontSize(Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE)
            .margin({ bottom: Theme.SPACING_XS })

          Text(this.card.detail)
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_REGULAR)
            .fontColor(Theme.ON_SURFACE_VARIANT)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text(this.card.category.length > 0 ? this.card.category :
            (this.language === 'zh' ? '未分类' : 'Uncategorized'))
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(this.card.accentColor)
            .padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM, top: 4, bottom: 4 })
            .backgroundColor(`${this.card.accentColor}12`)
            .borderRadius(Theme.RADIUS_FULL)
        }
        .width('100%')
        .margin({ top: Theme.SPACING_LG })
      }
      .width('100%')
      .padding(Theme.SPACING_LG)
    }
    .width('100%')
    .backgroundColor('rgba(255, 255, 255, 0.82)')
    .backdropBlur(24)
    .borderRadius(Theme.RADIUS_LG)
    .borderWidth(1)
    .borderColor('rgba(255, 255, 255, 0.6)')
    .shadow({ radius: 40, color: 'rgba(0, 0, 0, 0.1)', offsetY: 8 })
    .clip(true)
  }
}
