import { manager } from '@kit.NearLinkKit'
import * as Theme from '../common/Theme'
import {
  NearLinkConnectionService,
  NearLinkConnectionState,
  NearLinkDevice,
  NearLinkReceivedMessage
} from '../services/NearLinkConnectionService'

@Component
export struct ScanPage {
  @Link language: string
  @Link showScanPage: boolean
  @State supported: boolean = false
  @State nearLinkState: manager.NearlinkState = manager.NearlinkState.STATE_OFF
  @State connectionState: NearLinkConnectionState = NearLinkConnectionState.IDLE
  @State protocolState: NearLinkConnectionState = NearLinkConnectionState.IDLE
  @State devices: NearLinkDevice[] = []
  @State connectedAddress: string = ''
  @State lastMessage: string = '-'
  @State lastError: string = '-'
  private service: NearLinkConnectionService = NearLinkConnectionService.getInstance()

  aboutToAppear(): void {
    this.service.onDeviceDiscovered((devices: NearLinkDevice[]) => {
      this.devices = devices
    })
    this.service.onConnectionStateChanged((state: NearLinkConnectionState) => {
      this.connectionState = state
      if (state === NearLinkConnectionState.DISCONNECTED || state === NearLinkConnectionState.ERROR) {
        this.connectedAddress = ''
      }
    })
    this.service.onProtocolStateChanged((state: NearLinkConnectionState) => {
      this.protocolState = state
    })
    this.service.onMessageReceived((message: NearLinkReceivedMessage) => {
      this.lastMessage = `type=0x${message.type.toString(16).toUpperCase()} seq=${message.sequence}` +
        (message.payloadHex.length > 0 ? ` payload=${message.payloadHex}` : '')
    })
    this.service.onError((message: string) => {
      this.lastError = message
    })
    this.refreshCapability()
  }

  aboutToDisappear(): void {
    this.service.dispose().catch(() => {
      console.error('[SLEKEY][UI] dispose failed')
    })
  }

  build() {
    Scroll() {
      Column({ space: Theme.SPACING_MD }) {
        this.Header()
        this.CapabilityCard()
        this.ScanCard()

        ForEach(this.devices, (device: NearLinkDevice) => {
          this.DeviceCard(device)
        }, (device: NearLinkDevice) => device.address)

        this.ConnectionCard()
        this.DiagnosticsCard()
      }
      .width('100%')
      .padding({
        top: Theme.STATUS_BAR_PADDING,
        left: Theme.CONTAINER_MARGIN,
        right: Theme.CONTAINER_MARGIN,
        bottom: 120
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(Theme.BACKGROUND)
  }

  @Builder
  private Header() {
    Column() {
      Text(this.language === 'zh' ? '临时连接' : 'Temporary connection')
        .fontSize(Theme.HEADLINE_LG_MOBILE_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_BOLD)
        .fontColor(Theme.ON_SURFACE)

      Text(this.language === 'zh' ?
        '在应用内扫描并连接 BearPi_A，不会跳转系统设置。' :
        'Scan and connect to BearPi_A inside the app.')
        .fontSize(Theme.BODY_MD_FONT_SIZE)
        .fontColor(Theme.ON_SURFACE_VARIANT)
        .margin({ top: Theme.SPACING_XS })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private CapabilityCard() {
    Column({ space: Theme.SPACING_SM }) {
      this.StatusRow(this.language === 'zh' ? '星闪支持' : 'NearLink support',
        this.supported ? (this.language === 'zh' ? '支持' : 'Supported') :
          (this.language === 'zh' ? '不支持' : 'Unsupported'))
      this.StatusRow(this.language === 'zh' ? '星闪开关' : 'NearLink switch', this.nearLinkStateText())
      this.StatusRow(this.language === 'zh' ? '链路状态' : 'Link state', this.connectionState)
      this.StatusRow(this.language === 'zh' ? '协议状态' : 'Protocol state', this.protocolState)
    }
    .width('100%')
    .padding(Theme.SPACING_LG)
    .backgroundColor('rgba(255, 255, 255, 0.72)')
    .borderRadius(Theme.RADIUS_LG)
    .borderWidth(1)
    .borderColor('rgba(255, 255, 255, 0.76)')
  }

  @Builder
  private ScanCard() {
    Row() {
      Column() {
        Text(this.scanTitle())
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE)
        Text(this.language === 'zh' ? '10 秒后自动停止，按地址去重并刷新 RSSI' :
          'Stops after 10 seconds; deduplicates by address and refreshes RSSI')
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(this.connectionState === NearLinkConnectionState.SCANNING ?
        (this.language === 'zh' ? '停止' : 'Stop') :
        (this.language === 'zh' ? '扫描' : 'Scan'))
        .enabled(this.supported && !this.isLinkBusy())
        .backgroundColor(Theme.PRIMARY)
        .onClick(() => {
          this.lastError = '-'
          if (this.connectionState === NearLinkConnectionState.SCANNING) {
            this.service.stopScan().then(() => {
              this.connectionState = NearLinkConnectionState.IDLE
            })
          } else {
            this.refreshCapability()
            this.service.startScan()
          }
        })
    }
    .width('100%')
    .padding(Theme.SPACING_LG)
    .backgroundColor('rgba(255, 255, 255, 0.68)')
    .borderRadius(Theme.RADIUS_LG)
  }

  @Builder
  private DeviceCard(device: NearLinkDevice) {
    Row() {
      Column({ space: 3 }) {
        Text(device.name)
          .fontSize(Theme.BODY_MD_FONT_SIZE)
          .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
          .fontColor(Theme.ON_SURFACE)
        Text(device.address)
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
        Text(`RSSI ${device.rssi} dBm`)
          .fontSize(Theme.LABEL_SM_FONT_SIZE)
          .fontColor(Theme.ON_SURFACE_VARIANT)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(this.connectedAddress === device.address ?
        (this.language === 'zh' ? '已连接' : 'Connected') :
        (this.language === 'zh' ? '连接' : 'Connect'))
        .enabled(!this.isLinkBusy() && this.connectedAddress.length === 0)
        .backgroundColor(Theme.PRIMARY)
        .onClick(() => {
          this.lastError = '-'
          this.connectedAddress = device.address
          this.service.connect(device)
        })
    }
    .width('100%')
    .padding(Theme.SPACING_LG)
    .backgroundColor(Theme.SURFACE)
    .borderRadius(Theme.RADIUS_LG)
    .borderWidth(1)
    .borderColor('rgba(199, 196, 215, 0.30)')
  }

  @Builder
  private ConnectionCard() {
    Row({ space: Theme.SPACING_SM }) {
      Button(this.language === 'zh' ? '测试通信' : 'Ping')
        .layoutWeight(1)
        .enabled(this.connectionState === NearLinkConnectionState.READY)
        .backgroundColor(Theme.PRIMARY)
        .onClick(() => {
          this.lastError = '-'
          this.service.sendPing()
        })

      Button(this.language === 'zh' ? '设备信息' : 'Device info')
        .layoutWeight(1)
        .enabled(this.connectionState === NearLinkConnectionState.READY)
        .onClick(() => {
          this.service.readDeviceInfo()
        })

      Button(this.language === 'zh' ? '断开' : 'Disconnect')
        .layoutWeight(1)
        .enabled(this.connectedAddress.length > 0)
        .onClick(() => {
          this.service.disconnect()
        })
    }
    .width('100%')
  }

  @Builder
  private DiagnosticsCard() {
    Column({ space: Theme.SPACING_SM }) {
      this.StatusRow(this.language === 'zh' ? '最近消息' : 'Last message', this.lastMessage)
      this.StatusRow(this.language === 'zh' ? '最近错误' : 'Last error', this.lastError)
      Button(this.language === 'zh' ? '重新扫描 / 重试' : 'Scan again / Retry')
        .width('100%')
        .enabled(this.supported && !this.isLinkBusy())
        .onClick(() => {
          this.lastError = '-'
          this.service.startScan()
        })
    }
    .width('100%')
    .padding(Theme.SPACING_LG)
    .backgroundColor('rgba(255, 255, 255, 0.68)')
    .borderRadius(Theme.RADIUS_LG)
  }

  @Builder
  private StatusRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(Theme.LABEL_MD_FONT_SIZE)
        .fontColor(Theme.ON_SURFACE_VARIANT)
      Text(value)
        .layoutWeight(1)
        .fontSize(Theme.LABEL_MD_FONT_SIZE)
        .fontWeight(Theme.FONT_WEIGHT_SEMIBOLD)
        .fontColor(Theme.ON_SURFACE)
        .textAlign(TextAlign.End)
        .maxLines(2)
    }
    .width('100%')
  }

  private refreshCapability(): void {
    this.supported = this.service.isNearLinkSupported()
    if (!this.supported) {
      this.connectionState = NearLinkConnectionState.UNSUPPORTED
      return
    }
    try {
      this.nearLinkState = this.service.getNearLinkState()
      if (this.nearLinkState !== manager.NearlinkState.STATE_ON) {
        this.connectionState = NearLinkConnectionState.NEARLINK_OFF
      }
    } catch (error) {
      this.connectionState = NearLinkConnectionState.ERROR
      this.lastError = `${this.language === 'zh' ? '读取星闪状态失败' : 'Failed to read NearLink state'}: ${error}`
    }
  }

  private nearLinkStateText(): string {
    if (!this.supported) {
      return this.language === 'zh' ? '不可用' : 'Unavailable'
    }
    if (this.nearLinkState === manager.NearlinkState.STATE_ON) {
      return this.language === 'zh' ? '已开启' : 'On'
    }
    if (this.nearLinkState === manager.NearlinkState.STATE_TURNING_ON) {
      return this.language === 'zh' ? '开启中' : 'Turning on'
    }
    if (this.nearLinkState === manager.NearlinkState.STATE_TURNING_OFF) {
      return this.language === 'zh' ? '关闭中' : 'Turning off'
    }
    return this.language === 'zh' ? '未开启' : 'Off'
  }

  private scanTitle(): string {
    if (this.connectionState === NearLinkConnectionState.SCANNING) {
      return this.language === 'zh' ? '正在查找 SLEKEY-A…' : 'Looking for SLEKEY-A…'
    }
    return this.devices.length > 0 ?
      (this.language === 'zh' ? `发现 ${this.devices.length} 个设备` : `${this.devices.length} device(s) found`) :
      (this.language === 'zh' ? '尚未扫描' : 'Not scanned yet')
  }

  private isLinkBusy(): boolean {
    return this.connectionState === NearLinkConnectionState.CONNECTING ||
      this.connectionState === NearLinkConnectionState.HANDSHAKING ||
      this.connectionState === NearLinkConnectionState.DISCONNECTING
  }
}
