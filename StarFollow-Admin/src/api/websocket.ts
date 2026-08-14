import { getAccessToken } from './request'

export interface WsEnvelope<T = unknown> {
  version: 1
  seq: number
  topic: string
  sentAt: string
  data: T
}

type EventMessageHandler = (message: WsEnvelope) => void
type StateHandler = (connected: boolean) => void

const handlers = new Set<EventMessageHandler>()
const stateHandlers = new Set<StateHandler>()
let ws: WebSocket | null = null
let reconnectTimer: ReturnType<typeof setTimeout> | null = null
let reconnectAttempt = 0
let stopped = true
let configuredUrl: string | undefined

function socketUrl(url?: string): string {
  const target = url || import.meta.env.VITE_STARFOLLOW_WS_URL || `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/ws/events`
  const parsed = new URL(target, location.href)
  const token = getAccessToken()
  if (token) parsed.searchParams.set('access_token', token)
  return parsed.toString()
}

function notifyState(connected: boolean): void {
  stateHandlers.forEach(handler => handler(connected))
}

function scheduleReconnect(): void {
  if (stopped || reconnectTimer) return
  const delay = Math.min(30_000, 1000 * (2 ** Math.min(reconnectAttempt, 5)))
  reconnectAttempt += 1
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null
    openSocket()
  }, delay)
}

function openSocket(): void {
  if (stopped || ws?.readyState === WebSocket.OPEN || ws?.readyState === WebSocket.CONNECTING) return
  const socket = new WebSocket(socketUrl(configuredUrl))
  ws = socket
  socket.onopen = () => {
    reconnectAttempt = 0
    notifyState(true)
  }
  socket.onmessage = event => {
    try {
      const message = JSON.parse(String(event.data)) as WsEnvelope
      if (message.version === 1 && typeof message.topic === 'string') handlers.forEach(handler => handler(message))
    } catch (error) {
      console.error('[WebSocket] 消息解析失败', error)
    }
  }
  socket.onclose = () => {
    if (ws === socket) ws = null
    notifyState(false)
    scheduleReconnect()
  }
  socket.onerror = () => socket.close()
}

export function connectEventSocket(url?: string): void {
  configuredUrl = url
  stopped = false
  openSocket()
}

export function closeSocket(): void {
  stopped = true
  if (reconnectTimer) clearTimeout(reconnectTimer)
  reconnectTimer = null
  const socket = ws
  ws = null
  socket?.close()
  notifyState(false)
}

export function reconnectEventSocket(): void {
  closeSocket()
  connectEventSocket(configuredUrl)
}

export function onEventMessage(handler: EventMessageHandler): () => void {
  handlers.add(handler)
  return () => handlers.delete(handler)
}

export function onSocketState(handler: StateHandler): () => void {
  stateHandlers.add(handler)
  handler(isSocketConnected())
  return () => stateHandlers.delete(handler)
}

export function isSocketConnected(): boolean {
  return ws?.readyState === WebSocket.OPEN
}
