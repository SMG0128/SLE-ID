import { BottomNavBar } from '../components/BottomNavBar'
import { SideNavBar } from '../components/SideNavBar'
import { CardsPage } from './CardsPage'
import { CardDetailPage } from './CardDetailPage'
import { ProfilePage } from './ProfilePage'
import { ScanPage } from './ScanPage'
import { LanguagePage } from './LanguagePage'
import { MockSettingsPage } from './MockSettingsPage'
import { PhysicalCardManagerPage } from './PhysicalCardManagerPage'
import { CardPreview } from '../components/CardPreview'
import { DigitalCard, DigitalCardStatus } from '../models/DigitalCard'
import { CredentialBindingStatus } from '../models/Credential'
import {
  AuthorizationAlertPolicy,
  AuthorizationUsageMode
} from '../models/Authorization'
import {
  InvitationAuthorizationPreview,
  InvitationFailureReason,
  InvitationFlowState,
  InvitationPreviewResult,
  InvitationRedemptionResult
} from '../models/Invitation'
import { CardStore } from '../stores/CardStore'
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
  @State showPhysicalCardManagerPage: boolean = false
  @State showScanPage: boolean = false
  @State showVerificationDialog: boolean = false
  @State slideProgress: number = 0
  @StorageLink('verificationPending') verificationPending: boolean = false
  @StorageLink('verificationCardId') verificationCardId: string = '2'
  @State selectedCardId: string = '2'
  @State cardStore: CardStore = CardStore.getInstance()
  @State windowWidth: number = 0
  @State invitationCode: string = ''
  @State invitationState: InvitationFlowState = InvitationFlowState.IDLE
  @State invitationFailureReason: InvitationFailureReason = InvitationFailureReason.NONE
  @State invitationPreview: InvitationAuthorizationPreview | null = null
  private invitationOperationId: number = 0

  aboutToAppear(): void {
    this.cardStore.refresh().catch(() => {
      console.error('Unable to refresh mock card data')
    })
  }

  build() {
    Column() {
      if (this.windowWidth >= Theme.BREAKPOINT_TABLET) {
        // Tablet layout: side nav + content
        this.TabletLayout()
      } else {
        // Phone layout: stack + bottom nav
        this.PhoneLayout()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BACKGROUND)
    .onAreaChange((_oldVal: Area, newVal: Area) => {
      this.windowWidth = newVal.width as number
    })
  }

  @Builder
  TabletLayout() {
    Row() {
      // Side navigation
      if (!this.showLanguagePage && !this.showCardDetailPage &&
        !this.showMockSettingsPage && !this.showPhysicalCardManagerPage) {
        SideNavBar({
          currentIndex: $currentIndex,
          language: $language,
          showAddCardModal: $showAddCardModal,
          showPhysicalCardManagerPage: $showPhysicalCardManagerPage,
          showScanPage: $showScanPage
        })
          .zIndex(110)
      }

      // Content area
      Stack({ alignContent: Alignment.TopStart }) {
        this.ContentArea()

        if (this.showScanPage) {
          this.TabletScanPopover()
        }

        if (this.showAddCardModal) {
          this.AddCardModal()
        }

        if (this.showVerificationDialog || this.verificationPending) {
          this.VerificationDialog()
        }
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  TabletScanPopover() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(25, 28, 29, 0.12)')
        .onClick(() => {
          this.showScanPage = false
        })
        .transition(
          TransitionEffect.OPACITY
            .animation({ duration: 200, curve: Curve.EaseOut })
        )

      Stack({ alignContent: Alignment.TopEnd }) {
        ScanPage({
          language: $language,
          showScanPage: $showScanPage
        })
          .width('100%')
          .height('100%')

        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(Theme.ICON_MD)
            .fontColor([Theme.ON_SURFACE_VARIANT])
        }
        .width(40)
        .height(40)
        .borderRadius(Theme.RADIUS_FULL)
        .backgroundColor('rgba(255, 255, 255, 0.72)')
        .backdropBlur(20)
        .margin({ top: Theme.SPACING_MD, right: Theme.SPACING_MD })
        .zIndex(2)
        .onClick(() => {
          this.showScanPage = false
        })
      }
      .width(440)
      .height(620)
      .margin({ left: Theme.SPACING_LG, bottom: Theme.SPACING_LG })
      .backgroundColor('rgba(248, 249, 250, 0.94)')
      .backdropBlur(40)
      .borderRadius(Theme.RADIUS_LG)
      .borderWidth(1)
      .borderColor('rgba(255, 255, 255, 0.78)')
      .shadow({
        radius: 40,
        color: 'rgba(30, 34, 78, 0.18)',
        offsetY: 10
      })
      .clip(true)
      .transition(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ x: -60, y: 80 }))
          .combine(TransitionEffect.scale({ x: 0.8, y: 0.8 }))
          .animation({ duration: 400, curve: Curve.EaseOut })
      )
    }
    .width('100%')
    .height('100%')
    .zIndex(70)
  }

  @Builder
  PhoneLayout() {
    Stack({ alignContent: Alignment.Bottom }) {
      this.ContentArea()

      if (this.showAddCardModal) {
        this.AddCardModal()
      }

      if (!this.showLanguagePage && !this.showCardDetailPage &&
        !this.showMockSettingsPage && !this.showPhysicalCardManagerPage) {
        BottomNavBar({
          currentIndex: $currentIndex,
          language: $language,
          showScanPage: $showScanPage
        })
          .zIndex(110)
      }

      if (this.showVerificationDialog || this.verificationPending) {
        this.VerificationDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ContentArea() {
    if (this.showCardDetailPage) {
      CardDetailPage({
        cardStore: this.cardStore,
        language: $language,
        showCardDetailPage: $showCardDetailPage,
        selectedCardId: $selectedCardId,
        isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET,
        windowWidth: this.windowWidth
      })
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 40 }))
            .animation({ duration: Theme.ANIMATION_DURATION, curve: Curve.EaseInOut })
        )
    } else if (this.showPhysicalCardManagerPage) {
      PhysicalCardManagerPage({
        cardStore: this.cardStore,
        language: $language,
        showPhysicalCardManagerPage: $showPhysicalCardManagerPage
      })
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 40 }))
            .animation({ duration: Theme.ANIMATION_DURATION, curve: Curve.EaseInOut })
        )
    } else if (this.showLanguagePage) {
      LanguagePage({ language: $language, showLanguagePage: $showLanguagePage })
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 40 }))
            .animation({ duration: Theme.ANIMATION_DURATION, curve: Curve.EaseInOut })
        )
    } else if (this.showMockSettingsPage) {
      MockSettingsPage({
        language: $language,
        showMockSettingsPage: $showMockSettingsPage,
        showVerificationDialog: $showVerificationDialog
      })
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 40 }))
            .animation({ duration: Theme.ANIMATION_DURATION, curve: Curve.EaseInOut })
        )
    } else if (this.showScanPage && this.windowWidth < Theme.BREAKPOINT_TABLET) {
      ScanPage({
        language: $language,
        showScanPage: $showScanPage
      })
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 }))
            .animation({ duration: 550, curve: Curve.EaseInOut })
        )
    } else if (this.currentIndex === 0) {
      CardsPage({
        showAddCardModal: $showAddCardModal,
        language: $language,
        cardStore: this.cardStore,
        showCardDetailPage: $showCardDetailPage,
        selectedCardId: $selectedCardId,
        showMockSettingsPage: $showMockSettingsPage,
        showPhysicalCardManagerPage: $showPhysicalCardManagerPage,
        isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET
      })
    } else {
      ProfilePage({
        language: $language,
        showLanguagePage: $showLanguagePage,
        isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET,
        windowWidth: this.windowWidth
      })
    }
  }

  @Builder
  VerificationDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('120%')
        .height('120%')
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
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
        .animation({ duration: Theme.ANIMATION_DURATION, curve: Curve.EaseInOut })
    )
  }

  private verificationCard(): DigitalCard {
    let result: DigitalCard = this.cardStore.cards[0]
    this.cardStore.cards.forEach((card: DigitalCard) => {
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
      Column()
        .width('120%')
        .height('120%')
        .backgroundColor('rgba(0, 0, 0, 0.4)')
        .onClick(() => {
          this.closeAddCardModal()
        })

      Column() {
        Column() {
          Text(this.language === 'zh' ? '领取数字卡片' : 'Claim Digital Card')
            .fontSize(Theme.HEADLINE_MD_FONT_SIZE)
            .fontWeight(Theme.FONT_WEIGHT_BOLD)
            .fontColor(Theme.ON_SURFACE)
            .textAlign(TextAlign.Center)

          Text(this.language === 'zh' ? '输入管理方提供的邀请码' : 'Enter the invitation code from the issuer')
            .fontSize(Theme.BODY_MD_FONT_SIZE)
            .fontColor(Theme.ON_SURFACE_VARIANT)
            .opacity(0.7)
            .textAlign(TextAlign.Center)
            .margin({ top: Theme.SPACING_XS })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Scroll() {
          Column() {
            Column() {
              Stack({ alignContent: Alignment.End }) {
                TextInput({
                  text: this.invitationCode,
                  placeholder: this.language === 'zh' ? '例如 SLE-DEMO-2026' : 'e.g. SLE-DEMO-2026'
                })
                  .width('100%')
                  .height(56)
                  .fontSize(Theme.BODY_LG_FONT_SIZE)
                  .fontColor(Theme.ON_SURFACE)
                  .backgroundColor(Theme.SURFACE_CONTAINER_LOW)
                  .borderRadius(Theme.RADIUS_DEFAULT)
                  .padding({
                    left: Theme.SPACING_MD,
                    right: Theme.SPACING_MD + Theme.ICON_MD + Theme.SPACING_XS
                  })
                  .placeholderColor('rgba(70, 69, 84, 0.4)')
                  .maxLength(13)
                  .enabled(!this.isInvitationBusy())
                  .onChange((value: string) => {
                    this.onInvitationCodeChange(value)
                  })

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

                Text(this.language === 'zh' ? '邀请码格式：SLE-XXXX-XXXX' : 'Format: SLE-XXXX-XXXX')
                  .fontSize(Theme.LABEL_SM_FONT_SIZE)
                  .fontColor('rgba(70, 69, 84, 0.6)')
                  .margin({ left: Theme.SPACING_XS })
              }
              .width('100%')
              .margin({ top: Theme.SPACING_XS })
              .padding({ left: Theme.SPACING_BASE })
            }
            .width('100%')

            if (this.invitationState === InvitationFlowState.PREVIEW_READY && this.invitationPreview) {
              this.InvitationPreviewSection()
            } else if (this.invitationState !== InvitationFlowState.IDLE) {
              this.InvitationStateFeedback()
            }
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 520 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .margin({ top: Theme.SPACING_XL })

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
              this.closeAddCardModal()
            })

          Button(this.invitationPrimaryButtonText())
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
            .enabled(!this.isInvitationBusy())
            .onClick(() => {
              this.handleInvitationPrimaryAction()
            })
        }
        .width('100%')
        .margin({ top: Theme.SPACING_XL })
      }
      .width('90%')
      .constraintSize({ maxWidth: 520, maxHeight: '90%' })
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
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
        .animation({ duration: Theme.ANIMATION_DURATION, curve: Curve.EaseInOut })
    )
  }

  @Builder
  InvitationPreviewSection() {
    Column() {
      CardPreview({ card: this.invitationPreviewCard(), language: this.language })
        .width('100%')

      Column() {
        this.InvitationPreviewRow(
          this.language === 'zh' ? '签发方' : 'Issuer',
          this.invitationPreviewIssuer()
        )
        this.InvitationPreviewRow(
          this.language === 'zh' ? '权限范围' : 'Permission Scope',
          this.invitationPermissionScope()
        )
        this.InvitationPreviewRow(
          this.language === 'zh' ? '有效期' : 'Validity',
          this.invitationValidity()
        )
        this.InvitationPreviewRow(
          this.language === 'zh' ? '使用次数' : 'Usage',
          this.invitationUsageText()
        )
        this.InvitationPreviewRow(
          this.language === 'zh' ? '二次确认' : 'Confirmation',
          this.invitationConfirmationText()
        )
        this.InvitationPreviewRow(
          this.language === 'zh' ? '手机临时通行' : 'Phone Substitute',
          this.invitationPhoneSubstituteText()
        )
        this.InvitationPreviewRow(
          this.language === 'zh' ? '离线使用' : 'Offline Use',
          this.invitationOfflineText()
        )
        this.InvitationPreviewRow(
          this.language === 'zh' ? '提醒策略' : 'Alert Policy',
          this.invitationAlertPolicyText()
        )
      }
      .width('100%')
      .margin({ top: Theme.SPACING_MD })
      .padding(Theme.SPACING_MD)
      .backgroundColor(Theme.SURFACE_CONTAINER_LOW)
      .borderRadius(Theme.RADIUS_DEFAULT)
    }
    .width('100%')
    .margin({ top: Theme.SPACING_LG })
  }

  @Builder
  InvitationPreviewRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(Theme.LABEL_MD_FONT_SIZE)
        .fontColor(Theme.ON_SURFACE_VARIANT)

      Text(value)
        .fontSize(Theme.LABEL_MD_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE)
        .textAlign(TextAlign.End)
        .layoutWeight(1)
        .maxLines(3)
        .margin({ left: Theme.SPACING_MD })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: Theme.SPACING_XS, bottom: Theme.SPACING_XS })
  }

  @Builder
  InvitationStateFeedback() {
    Row() {
      SymbolGlyph(this.isInvitationError() ?
        $r('sys.symbol.exclamationmark_circle') : $r('sys.symbol.clock'))
        .fontSize(Theme.ICON_MD)
        .fontColor([this.isInvitationError() ? Theme.ERROR : Theme.PRIMARY])

      Text(this.invitationStateMessage())
        .fontSize(Theme.BODY_MD_FONT_SIZE)
        .fontColor(this.isInvitationError() ? Theme.ERROR : Theme.ON_SURFACE_VARIANT)
        .layoutWeight(1)
        .margin({ left: Theme.SPACING_SM })
    }
    .width('100%')
    .padding(Theme.SPACING_MD)
    .margin({ top: Theme.SPACING_LG })
    .backgroundColor(this.isInvitationError() ? 'rgba(186, 26, 26, 0.08)' :
      Theme.SURFACE_CONTAINER_LOW)
    .borderRadius(Theme.RADIUS_DEFAULT)
  }

  private handleInvitationPrimaryAction(): void {
    if (this.invitationState === InvitationFlowState.PREVIEW_READY) {
      this.redeemInvitation().catch(() => {
        this.applyInvitationRequestError()
      })
      return
    }
    if (this.isInvitationBusy()) {
      return
    }
    this.loadInvitationPreview().catch(() => {
      this.applyInvitationRequestError()
    })
  }

  private async loadInvitationPreview(): Promise<void> {
    const normalizedCode: string = this.invitationCode.trim().toUpperCase()
    this.invitationCode = normalizedCode
    this.invitationPreview = null
    if (normalizedCode.length === 0) {
      this.invitationState = InvitationFlowState.INVALID
      this.invitationFailureReason = InvitationFailureReason.EMPTY
      return
    }
    if (!this.cardStore.validateInvitationFormat(normalizedCode)) {
      this.invitationState = InvitationFlowState.INVALID
      this.invitationFailureReason = InvitationFailureReason.FORMAT
      return
    }

    const operationId: number = ++this.invitationOperationId
    this.invitationState = InvitationFlowState.VALIDATING
    this.invitationFailureReason = InvitationFailureReason.NONE
    const result: InvitationPreviewResult =
      await this.cardStore.previewInvitation(normalizedCode)
    if (!this.isInvitationOperationActive(operationId)) {
      return
    }
    this.invitationState = result.state
    this.invitationFailureReason = result.reason
    this.invitationPreview = result.preview
  }

  private async redeemInvitation(): Promise<void> {
    if (this.invitationState !== InvitationFlowState.PREVIEW_READY ||
      !this.invitationPreview) {
      return
    }

    const operationId: number = ++this.invitationOperationId
    this.invitationState = InvitationFlowState.REDEEMING
    this.invitationFailureReason = InvitationFailureReason.NONE
    const result: InvitationRedemptionResult =
      await this.cardStore.redeemInvitation(this.invitationCode)
    if (!this.isInvitationOperationActive(operationId)) {
      return
    }

    this.invitationState = result.state
    this.invitationFailureReason = result.reason
    this.invitationPreview = result.preview
    if (result.state !== InvitationFlowState.SUCCESS) {
      return
    }

    this.showAddCardModal = false
    this.invitationOperationId++
    this.resetInvitationFlow()
    try {
      this.getUIContext().getPromptAction().showToast({
        message: this.language === 'zh' ? '数字卡片领取成功' : 'Digital card claimed'
      })
    } catch (error) {
      console.error('Unable to show invitation redemption result')
    }
  }

  private closeAddCardModal(): void {
    this.invitationOperationId++
    this.showAddCardModal = false
    this.resetInvitationFlow()
  }

  private resetInvitationFlow(): void {
    this.invitationCode = ''
    this.invitationState = InvitationFlowState.IDLE
    this.invitationFailureReason = InvitationFailureReason.NONE
    this.invitationPreview = null
  }

  private onInvitationCodeChange(value: string): void {
    this.invitationOperationId++
    this.invitationCode = value
    this.invitationState = InvitationFlowState.IDLE
    this.invitationFailureReason = InvitationFailureReason.NONE
    this.invitationPreview = null
  }

  private applyInvitationRequestError(): void {
    if (!this.showAddCardModal) {
      return
    }
    this.invitationState = InvitationFlowState.REQUEST_ERROR
    this.invitationFailureReason = InvitationFailureReason.REQUEST_ERROR
    this.invitationPreview = null
  }

  private isInvitationOperationActive(operationId: number): boolean {
    return this.showAddCardModal && operationId === this.invitationOperationId
  }

  private isInvitationBusy(): boolean {
    return this.invitationState === InvitationFlowState.VALIDATING ||
      this.invitationState === InvitationFlowState.REDEEMING
  }

  private isInvitationError(): boolean {
    return this.invitationState === InvitationFlowState.INVALID ||
      this.invitationState === InvitationFlowState.EXPIRED ||
      this.invitationState === InvitationFlowState.ALREADY_USED ||
      this.invitationState === InvitationFlowState.ALREADY_BOUND ||
      this.invitationState === InvitationFlowState.REQUEST_ERROR
  }

  private invitationPrimaryButtonText(): string {
    if (this.invitationState === InvitationFlowState.PREVIEW_READY) {
      return this.language === 'zh' ? '确认领取' : 'Claim Card'
    }
    if (this.invitationState === InvitationFlowState.VALIDATING) {
      return this.language === 'zh' ? '正在验证' : 'Validating'
    }
    if (this.invitationState === InvitationFlowState.REDEEMING) {
      return this.language === 'zh' ? '正在领取' : 'Claiming'
    }
    return this.language === 'zh' ? '验证邀请码' : 'Validate Code'
  }

  private invitationStateMessage(): string {
    if (this.invitationState === InvitationFlowState.VALIDATING) {
      return this.language === 'zh' ? '正在验证邀请码…' : 'Validating invitation code…'
    }
    if (this.invitationState === InvitationFlowState.REDEEMING) {
      return this.language === 'zh' ? '正在领取许可…' : 'Claiming authorization…'
    }
    if (this.invitationFailureReason === InvitationFailureReason.EMPTY) {
      return this.language === 'zh' ? '请输入邀请码' : 'Enter an invitation code'
    }
    if (this.invitationFailureReason === InvitationFailureReason.FORMAT) {
      return this.language === 'zh' ? '邀请码格式不正确' : 'Invalid invitation code format'
    }
    if (this.invitationFailureReason === InvitationFailureReason.NOT_FOUND) {
      return this.language === 'zh' ? '邀请码不存在' : 'Invitation code not found'
    }
    if (this.invitationState === InvitationFlowState.EXPIRED) {
      return this.language === 'zh' ? '邀请码已过期' : 'Invitation code has expired'
    }
    if (this.invitationState === InvitationFlowState.ALREADY_USED) {
      return this.language === 'zh' ? '邀请码已经使用' : 'Invitation code has already been used'
    }
    if (this.invitationState === InvitationFlowState.ALREADY_BOUND) {
      return this.language === 'zh' ? '该许可已经在你的卡包中' :
        'This authorization is already in your wallet'
    }
    return this.language === 'zh' ? '暂时无法验证邀请码，请稍后重试' :
      'Unable to validate the invitation code. Try again later.'
  }

  private invitationPreviewCard(): DigitalCard {
    if (!this.invitationPreview) {
      return this.cardStore.cards[0]
    }
    return {
      id: 'invitation-preview',
      name: this.invitationPreview.cardName,
      issuer: this.invitationPreview.issuerName,
      anonymousNumber: 'PREVIEW 0000 0000',
      nickname: this.invitationPreview.cardName,
      detail: this.invitationPreview.cardDescription,
      category: this.invitationPreview.category,
      status: DigitalCardStatus.ACTIVE,
      visualStyle: this.invitationPreview.cardAppearance,
      authorizationId: this.invitationPreview.authorizationId,
      credentialId: '',
      physicalCardId: '',
      credentialBindingStatus: CredentialBindingStatus.NOT_WRITTEN,
      adminConfirmationRequired: this.invitationPreview.adminConfirmationRequired,
      userConfirmationEnabled: false,
      allowTemporaryPass: this.invitationPreview.phoneSubstituteAllowed,
      validFrom: this.invitationPreview.validFrom,
      validUntil: this.invitationPreview.validUntil,
      lastSyncedAt: ''
    }
  }

  private invitationPreviewIssuer(): string {
    return this.invitationPreview ? this.invitationPreview.issuerName : ''
  }

  private invitationPermissionScope(): string {
    if (!this.invitationPreview) {
      return ''
    }
    return this.invitationPreview.permissionScope.join(this.language === 'zh' ? '、' : ', ')
  }

  private invitationValidity(): string {
    if (!this.invitationPreview) {
      return ''
    }
    return `${this.invitationPreview.validFrom.substring(0, 10)} – ` +
      this.invitationPreview.validUntil.substring(0, 10)
  }

  private invitationUsageText(): string {
    if (!this.invitationPreview) {
      return ''
    }
    if (this.invitationPreview.usageMode === AuthorizationUsageMode.UNLIMITED) {
      return this.language === 'zh' ? '不限次数' : 'Unlimited'
    }
    return this.language === 'zh' ? `${this.invitationPreview.usageLimit} 次` :
      `${this.invitationPreview.usageLimit} uses`
  }

  private invitationConfirmationText(): string {
    if (this.invitationPreview && this.invitationPreview.adminConfirmationRequired) {
      return this.language === 'zh' ? '管理方要求二次确认' : 'Required by administrator'
    }
    return this.language === 'zh' ? '可由用户自行开启' : 'Optional'
  }

  private invitationPhoneSubstituteText(): string {
    if (this.invitationPreview && this.invitationPreview.phoneSubstituteAllowed) {
      return this.language === 'zh' ? '允许' : 'Allowed'
    }
    return this.language === 'zh' ? '不允许' : 'Not allowed'
  }

  private invitationOfflineText(): string {
    if (this.invitationPreview && this.invitationPreview.offlineAllowed) {
      return this.language === 'zh' ? '允许' : 'Allowed'
    }
    return this.language === 'zh' ? '不允许' : 'Not allowed'
  }

  private invitationAlertPolicyText(): string {
    if (!this.invitationPreview) {
      return ''
    }
    if (this.invitationPreview.alertPolicy === AuthorizationAlertPolicy.HIGH_ATTENTION) {
      return this.language === 'zh' ? '重点提醒' : 'High attention'
    }
    if (this.invitationPreview.alertPolicy === AuthorizationAlertPolicy.NOTIFY_ON_USE) {
      return this.language === 'zh' ? '使用时提醒' : 'Notify on use'
    }
    return this.language === 'zh' ? '默认' : 'Default'
  }
}
