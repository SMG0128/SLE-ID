import { BusinessError } from '@kit.BasicServicesKit'
import { webSocket } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { mobileWebSocketUrl } from './BackendConfigService'
import {
  boundedReconnectDelay,
  MobileWebSocketRouter
} from './MobileWebSocketRouter'
import { SessionStore } from '../stores/SessionStore'

export enum MobileWebSocketState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected'
}

export type MobileWebSocketConnectedHandler = () => void

interface MobileWebSocketHeaders {
  Authorization: string
}

export class MobileWebSocketClient {
  state: MobileWebSocketState = MobileWebSocketState.DISCONNECTED

  private readonly baseUrl: string
  private readonly sessionStore: SessionStore
  private readonly router: MobileWebSocketRouter
  private readonly connectedHandler: MobileWebSocketConnectedHandler
  private socket: webSocket.WebSocket | null = null
  private reconnectTimer: number = -1
  private reconnectAttempt: number = 0
  private shouldReconnect: boolean = false

  constructor(
    baseUrl: string,
    sessionStore: SessionStore,
    router: MobileWebSocketRouter,
    connectedHandler: MobileWebSocketConnectedHandler
  ) {
    this.baseUrl = baseUrl
    this.sessionStore = sessionStore
    this.router = router
    this.connectedHandler = connectedHandler
  }

  start(): void {
    this.shouldReconnect = true
    this.connect().catch(() => {
      this.scheduleReconnect()
    })
  }

  async stop(): Promise<void> {
    this.shouldReconnect = false
    if (this.reconnectTimer >= 0) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = -1
    }
    const activeSocket: webSocket.WebSocket | null = this.socket
    this.socket = null
    this.state = MobileWebSocketState.DISCONNECTED
    if (!activeSocket) {
      return
    }
    activeSocket.off('open')
    activeSocket.off('message')
    activeSocket.off('close')
    activeSocket.off('error')
    try {
      await activeSocket.close({ code: 1000, reason: 'Mobile lifecycle stop' })
    } catch (error) {
      throw new Error('Unable to close mobile WebSocket')
    }
  }

  private async connect(): Promise<void> {
    if (!this.shouldReconnect ||
      this.state === MobileWebSocketState.CONNECTING ||
      this.state === MobileWebSocketState.CONNECTED ||
      !this.sessionStore.hasUsableSession()) {
      return
    }
    this.state = MobileWebSocketState.CONNECTING
    const socket: webSocket.WebSocket = webSocket.createWebSocket()
    this.socket = socket
    socket.on('open', (error: BusinessError, value: Object) => {
      if (error) {
        this.state = MobileWebSocketState.DISCONNECTED
        this.scheduleReconnect()
        return
      }
      this.state = MobileWebSocketState.CONNECTED
      this.reconnectAttempt = 0
      this.connectedHandler()
    })
    socket.on('message', (error: BusinessError, data: string | ArrayBuffer) => {
      if (!error && typeof data === 'string') {
        this.router.route(data).catch(() => {
          hilog.warn(0x0000, 'SleKey', 'Mobile WebSocket message handling failed.')
        })
      }
    })
    socket.on('close', (error: BusinessError, value: webSocket.CloseResult) => {
      this.state = MobileWebSocketState.DISCONNECTED
      this.socket = null
      if (this.shouldReconnect) {
        this.scheduleReconnect()
      }
    })
    socket.on('error', (error: BusinessError) => {
      this.state = MobileWebSocketState.DISCONNECTED
      if (this.socket === socket) {
        this.socket = null
      }
      socket.off('open')
      socket.off('message')
      socket.off('close')
      socket.off('error')
      socket.close({ code: 1001, reason: 'Connection error' }).catch(() => {
        hilog.warn(0x0000, 'SleKey', 'Failed to close errored mobile WebSocket.')
      })
      if (this.shouldReconnect) {
        this.scheduleReconnect()
      }
    })
    const header: MobileWebSocketHeaders = {
      Authorization: `Bearer ${this.sessionStore.accessToken()}`
    }
    try {
      await socket.connect(mobileWebSocketUrl(this.baseUrl), {
        header: header
      })
    } catch (error) {
      this.state = MobileWebSocketState.DISCONNECTED
      this.socket = null
      socket.off('open')
      socket.off('message')
      socket.off('close')
      socket.off('error')
      throw new Error('Unable to connect mobile WebSocket')
    }
  }

  private scheduleReconnect(): void {
    if (!this.shouldReconnect || this.reconnectTimer >= 0 ||
      !this.sessionStore.hasUsableSession()) {
      return
    }
    const delay: number = boundedReconnectDelay(this.reconnectAttempt)
    this.reconnectAttempt++
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1
      this.connect().catch(() => {
        this.scheduleReconnect()
      })
    }, delay)
  }
}
