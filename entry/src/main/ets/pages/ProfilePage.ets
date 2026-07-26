import * as Theme from '../common/Theme'

interface SettingsItem {
  icon: Resource
  iconColor: string
  title: string
  hasArrow: boolean
  hasToggle: boolean
  toggleValue?: boolean
  trailingText?: string
  isExternal?: boolean
  isError?: boolean
  action?: string
}

@Component
export struct ProfilePage {
  @State isBiometricEnabled: boolean = true
  @Link language: string
  @Link showLanguagePage: boolean

  build() {
    Column() {
      // Top App Bar
      this.TopAppBar()

      // Scrollable content
      Scroll() {
        Column() {
          // User account section
          this.UserAccountSection()

          // Settings groups
          Column() {
            // Security & Identity
            this.SettingsGroup(this.language === 'zh' ? '安全与身份' : 'Security & Identity', [
              {
                icon: $r('sys.symbol.lock_shield'),
                iconColor: Theme.PRIMARY_CONTAINER,
                title: this.language === 'zh' ? '账户安全' : 'Account Security',
                hasArrow: true,
                hasToggle: false
              },
              {
                icon: $r('sys.symbol.lock_shield'),
                iconColor: Theme.PRIMARY_CONTAINER,
                title: this.language === 'zh' ? '生物识别登录' : 'Biometric Login',
                hasArrow: false,
                hasToggle: true,
                toggleValue: this.isBiometricEnabled
              },
              {
                icon: $r('sys.symbol.lock_shield'),
                iconColor: Theme.PRIMARY_CONTAINER,
                title: this.language === 'zh' ? '隐私与共享' : 'Privacy & Sharing',
                hasArrow: true,
                hasToggle: false
              }
            ])

            // Preferences
            this.SettingsGroup(this.language === 'zh' ? '偏好设置' : 'Preferences', [
              {
                icon: $r('sys.symbol.bell'),
                iconColor: Theme.TERTIARY_CONTAINER,
                title: this.language === 'zh' ? '通知' : 'Notifications',
                hasArrow: true,
                hasToggle: false
              },
              {
                icon: $r('sys.symbol.paintpalette'),
                iconColor: Theme.TERTIARY_CONTAINER,
                title: this.language === 'zh' ? '外观' : 'Appearance',
                hasArrow: true,
                hasToggle: false,
                trailingText: this.language === 'zh' ? '浅色' : 'Light'
              },
              {
                icon: $r('sys.symbol.key'),
                iconColor: Theme.TERTIARY_CONTAINER,
                title: this.language === 'zh' ? '通用' : 'General',
                hasArrow: false,
                hasToggle: false
              },
              {
                icon: $r('sys.symbol.arrow_up_right'),
                iconColor: Theme.TERTIARY_CONTAINER,
                title: this.language === 'zh' ? '语言' : 'Language',
                hasArrow: true,
                hasToggle: false,
                trailingText: this.language === 'zh' ? '中文' : 'English',
                action: 'language'
              }
            ])

            // Support
            this.SettingsGroup(this.language === 'zh' ? '支持' : 'Support', [
              {
                icon: $r('sys.symbol.questionmark_circle'),
                iconColor: Theme.ON_SURFACE_VARIANT,
                title: this.language === 'zh' ? '帮助中心' : 'Help Center',
                hasArrow: true,
                hasToggle: false,
                isExternal: true
              },
              {
                icon: $r('sys.symbol.arrow_up_right'),
                iconColor: Theme.ERROR,
                title: this.language === 'zh' ? '退出登录' : 'Sign Out',
                hasArrow: false,
                hasToggle: false,
                isError: true
              }
            ])
          }
          .margin({ top: Theme.SPACING_XL })

          // Version info
          Text(this.language === 'zh' ? '版本 4.12.0（构建 992）' : 'Version 4.12.0 (Build 992)')
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.OUTLINE_VARIANT)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: Theme.SPACING_XL })
        }
        .width('100%')
        .padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN, bottom: 120 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BACKGROUND)
    .padding({ top: Theme.STATUS_BAR_PADDING })
  }

  @Builder
  TopAppBar() {
    Row() {
      Blank()

      Text(this.language === 'zh' ? '个人中心' : 'Profile')
        .fontSize(Theme.TITLE_LG_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.PRIMARY)

      Blank()

      SymbolGlyph($r('sys.symbol.questionmark_circle'))
        .fontSize(Theme.ICON_LG)
        .fontColor([Theme.ON_SURFACE_VARIANT])
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
  UserAccountSection() {
    Column() {
      // Avatar
      Stack() {
        Stack() {
          Image($r('app.media.layered_image'))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        }
        .width(96)
        .height(96)
        .borderRadius(Theme.RADIUS_FULL)
        .clip(true)
        .borderWidth(2)
        .borderColor(Color.White)
        .shadow({
          radius: 16,
          color: 'rgba(0, 0, 0, 0.08)',
          offsetY: 4
        })

        // Edit button
        Stack() {
          SymbolGlyph($r('sys.symbol.paintpalette'))
            .fontSize(14)
            .fontColor([Theme.ON_PRIMARY_CONTAINER])
        }
        .width(28)
        .height(28)
        .borderRadius(Theme.RADIUS_FULL)
        .backgroundColor(Theme.PRIMARY_CONTAINER)
        .borderWidth(2)
        .borderColor(Color.White)
        .shadow({
          radius: 8,
          color: 'rgba(0, 0, 0, 0.08)',
          offsetY: 2
        })
        .position({ x: 68, y: 68 })
        .alignContent(Alignment.Center)
      }
      .width(96)
      .height(96)
      .margin({ bottom: Theme.SPACING_MD })

      // Name
      Text(this.language === 'zh' ? '亚历克斯·约翰逊' : 'Alex Johnson')
        .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE)

      // Membership info
      Text(this.language === 'zh' ? '高级会员 · ID：8820-XL' : 'Premium Member • ID: 8820-XL')
        .fontSize(Theme.BODY_MD_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_REGULAR)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .opacity(0.7)
        .margin({ top: Theme.SPACING_XS })

      // Stats row
      Row() {
        // Level
        Column() {
          Text(this.language === 'zh' ? '等级' : 'Level')
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
            .textCase(TextCase.Normal)
            .margin({ bottom: Theme.SPACING_XS })

          Text(this.language === 'zh' ? '黄金' : 'Gold')
            .fontSize(Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.PRIMARY)
        }
        .flexGrow(1)
        .alignItems(HorizontalAlign.Center)
        .padding(Theme.SPACING_MD)
        .backgroundColor(Theme.SURFACE_CONTAINER_LOW)
        .borderRadius(Theme.RADIUS_MD)

        // Points
        Column() {
          Text(this.language === 'zh' ? '积分' : 'Points')
            .fontSize(Theme.LABEL_SM_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
            .textCase(TextCase.Normal)
            .margin({ bottom: Theme.SPACING_XS })

          Text('12,450')
            .fontSize(Theme.TITLE_LG_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
            .fontColor(Theme.PRIMARY)
        }
        .flexGrow(1)
        .alignItems(HorizontalAlign.Center)
        .padding(Theme.SPACING_MD)
        .backgroundColor(Theme.SURFACE_CONTAINER_LOW)
        .borderRadius(Theme.RADIUS_MD)
        .margin({ left: Theme.SPACING_MD })
      }
      .width('100%')
      .margin({ top: Theme.SPACING_LG })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding(Theme.SPACING_LG)
    .backgroundColor('rgba(255, 255, 255, 0.8)')
    .backdropBlur(20)
    .borderRadius(Theme.RADIUS_LG)
    .borderWidth(1)
    .borderColor('rgba(255, 255, 255, 0.5)')
    .shadow({
      radius: 20,
      color: 'rgba(0, 0, 0, 0.04)',
      offsetY: 4
    })
  }

  @Builder
  SettingsGroup(title: string, items: SettingsItem[]) {
    Column() {
      Text(title)
        .fontSize(Theme.LABEL_SM_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .letterSpacing(Theme.LABEL_SM_LETTER_SPACING)
        .textCase(TextCase.Normal)
        .margin({ left: Theme.SPACING_SM, bottom: Theme.SPACING_XS })

      Column() {
        ForEach(items, (item: SettingsItem, index: number) => {
          Row() {
            SymbolGlyph(item.icon)
              .fontSize(Theme.ICON_LG)
              .fontColor([item.iconColor])
              .margin({ right: Theme.SPACING_MD })

            Text(item.title)
              .fontSize(Theme.BODY_MD_FONT_SIZE)
              .fontWeight(Theme.FONT_WEIGHT_REGULAR)
              .fontColor(item.isError ? Theme.ERROR : Theme.ON_SURFACE)
              .layoutWeight(1)

            if (item.trailingText) {
              Text(item.trailingText)
                .fontSize(Theme.LABEL_MD_FONT_SIZE)
                .fontWeight(Theme.FONT_WEIGHT_MEDIUM)
                .fontColor(Theme.ON_SURFACE_VARIANT)
                .margin({ right: Theme.SPACING_XS })
            }

            if (item.hasToggle) {
              Toggle({ type: ToggleType.Switch, isOn: item.toggleValue })
                .selectedColor(Theme.PRIMARY)
                .switchPointColor(Color.White)
                .width(44)
                .height(24)
                .onChange((isOn: boolean) => {
                  if (item.title === 'Biometric Login' || item.title === '生物识别登录') {
                    this.isBiometricEnabled = isOn
                  }
                })
            }

            if (item.hasArrow) {
              SymbolGlyph(item.isExternal ? $r('sys.symbol.arrow_up_right') : $r('sys.symbol.chevron_right'))
                .fontSize(Theme.ICON_MD)
                .fontColor([Theme.OUTLINE_VARIANT])
            }
          }
          .width('100%')
          .padding({ left: Theme.SPACING_LG, right: Theme.SPACING_LG, top: Theme.SPACING_MD, bottom: Theme.SPACING_MD })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            if (item.action === 'language') {
              this.showLanguagePage = true
            }
          })

          if (index < items.length - 1) {
            Divider()
              .color('rgba(199, 196, 215, 0.1)')
              .margin({ left: Theme.SPACING_LG, right: Theme.SPACING_LG })
          }
        })
      }
      .width('100%')
      .backgroundColor('rgba(255, 255, 255, 0.8)')
      .backdropBlur(20)
      .borderRadius(Theme.RADIUS_LG)
      .clip(true)
      .borderWidth(1)
      .borderColor('rgba(255, 255, 255, 0.5)')
      .shadow({
        radius: 20,
        color: 'rgba(0, 0, 0, 0.04)',
        offsetY: 4
      })
    }
    .width('100%')
    .margin({ bottom: Theme.SPACING_XL })
  }
}
