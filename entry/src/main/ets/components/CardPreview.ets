import * as Theme from '../common/Theme'
import { DigitalCard, DigitalCardStatus } from '../models/DigitalCard'
import {
  CredentialBindingStatus,
  CredentialCondition
} from '../models/Credential'
import { cardAccentColor, cardIcon } from '../common/CardModel'

@Component
export struct CardPreview {
  @Prop card: DigitalCard
  @Prop language: string
  @Prop isTablet: boolean = false

  build() {
    Column() {
      Stack() {
        Circle()
          .width(this.isTablet ? 150 : 192)
          .height(this.isTablet ? 150 : 192)
          .fill(cardAccentColor(this.card))
          .opacity(0.05)
      }
      .width('100%')
      .alignContent(Alignment.TopEnd)
      .position({ x: 0, y: 0 })
      .offset({ x: 48, y: -48 })

      Column() {
        Row({ space: 4 }) {
          Stack() {
            SymbolGlyph(cardIcon(this.card))
              .fontSize(this.isTablet ? Theme.ICON_MD : Theme.ICON_LG)
              .fontColor([Theme.ON_PRIMARY])
          }
          .width(this.isTablet ? 40 : 48)
          .height(this.isTablet ? 40 : 48)
          .borderRadius(Theme.RADIUS_FULL)
          .backgroundColor(cardAccentColor(this.card))
          .shadow({ radius: 16, color: cardAccentColor(this.card), offsetY: 4 })

          Blank()

          Text(this.statusText())
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(this.card.status === DigitalCardStatus.ACTIVE ?
              cardAccentColor(this.card) : Theme.ON_SURFACE_VARIANT)
            .maxLines(1)
            .padding({
              left: this.isTablet ? Theme.SPACING_XS : Theme.SPACING_MD,
              right: this.isTablet ? Theme.SPACING_XS : Theme.SPACING_MD,
              top: 4,
              bottom: 4
            })
            .backgroundColor(this.card.status === DigitalCardStatus.ACTIVE ?
              `${cardAccentColor(this.card)}1A` : Theme.SURFACE_CONTAINER_HIGH)
            .borderRadius(Theme.RADIUS_FULL)
        }
        .width('100%')
        .margin({ bottom: this.isTablet ? Theme.SPACING_MD : Theme.SPACING_XL })

        Column() {
          Text(this.card.nickname.length > 0 ? this.card.nickname : this.card.name)
            .fontSize(this.isTablet ? Theme.BODY_LG_FONT_SIZE : Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE)
            .margin({ bottom: Theme.SPACING_XS })

          Text(this.card.detail)
            .fontSize(this.isTablet ? Theme.LABEL_MD_FONT_SIZE : Theme.BODY_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_REGULAR)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text(this.card.category.length > 0 ? this.card.category :
            (this.language === 'zh' ? '未分类' : 'Uncategorized'))
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(cardAccentColor(this.card))
            .padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM, top: 4, bottom: 4 })
            .backgroundColor(`${cardAccentColor(this.card)}12`)
            .borderRadius(Theme.RADIUS_FULL)
        }
        .width('100%')
        .margin({ top: this.isTablet ? Theme.SPACING_MD : Theme.SPACING_LG })
      }
      .width('100%')
      .padding(this.isTablet ? 18 : Theme.SPACING_LG)
    }
    .width('100%')
    .backgroundColor('rgba(255, 255, 255, 0.82)')
    .backdropBlur(24)
    .borderRadius(Theme.RADIUS_LG)
    .borderWidth(1)
    .borderColor('rgba(255, 255, 255, 0.6)')
    .shadow({ radius: 40, color: 'rgba(0, 0, 0, 0.1)', offsetY: 8 })
    .constraintSize({ minHeight: this.isTablet ? Theme.TABLET_CARD_MIN_HEIGHT : 0 })
    .clip(true)
  }

  private statusText(): string {
    if (this.isTablet) {
      if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITING ||
        this.card.credentialBindingStatus === CredentialBindingStatus.VERIFYING) {
        return this.language === 'zh' ? '写入中' : 'Writing'
      }
      if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITE_FAILED) {
        return this.language === 'zh' ? '写入失败' : 'Failed'
      }
      if (this.card.credentialCondition === CredentialCondition.UPDATE_REQUIRED) {
        return this.language === 'zh' ? '需要更新' : 'Update'
      }
      if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITTEN) {
        return this.language === 'zh' ? '已写入' : 'Written'
      }
      if (this.card.status === DigitalCardStatus.ACTIVE) {
        return this.language === 'zh' ? '未写卡' : 'Not written'
      }
      return this.language === 'zh' ? '未启用' : 'Disabled'
    }
    if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITING ||
      this.card.credentialBindingStatus === CredentialBindingStatus.VERIFYING) {
      return this.language === 'zh' ? '正在写入实体卡' : 'Writing to WS63'
    }
    if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITE_FAILED) {
      return this.language === 'zh' ? '写入失败' : 'Write failed'
    }
    if (this.card.credentialCondition === CredentialCondition.UPDATE_REQUIRED) {
      return this.language === 'zh' ? '凭证需要更新' : 'Credential update required'
    }
    if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITTEN) {
      return this.language === 'zh' ? '已写入实体卡' : 'Written to WS63'
    }
    if (this.card.status === DigitalCardStatus.ACTIVE) {
      return this.language === 'zh' ? '尚未写入实体卡' : 'Not written to WS63'
    }
    return this.language === 'zh' ? '未启用' : 'Disabled'
  }
}
