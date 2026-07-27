/**
 * WebSocket 实时事件推送 — 预留模块
 *
 * 待后端 WS63 通信模块就绪后接入，
 * 用于接收设备实时感知事件、报警推送、设备心跳等。
 *
 * 当前通过 Mock 定时轮询模拟实时效果。
 */

type MessageHandler = (data: unknown) => void

const handlers = new Map<string, Set<MessageHandler>>()

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function connect(_url?: string): void {
  // TODO: 建立 WebSocket 连接
  // const ws = new WebSocket(url || 'ws://localhost:8080/ws')
  // ws.onmessage = (event) => { ... }
  console.log('[WebSocket] 模块已加载，等待后端就绪')
}

export function subscribe(channel: string, handler: MessageHandler): void {
  if (!handlers.has(channel)) {
    handlers.set(channel, new Set())
  }
  handlers.get(channel)!.add(handler)
}

export function unsubscribe(channel: string, handler: MessageHandler): void {
  handlers.get(channel)?.delete(handler)
}

export function emit(channel: string, data: unknown): void {
  handlers.get(channel)?.forEach((fn) => fn(data))
}

export function disconnect(): void {
  handlers.clear()
}
