/**
 * WebSocket 实时事件推送接口 — Ark Web 容器适配层
 *
 * 当前阶段：暂不连接真实 WebSocket，仅提供接口预留。
 * 后端 WS63 通信模块就绪后，取消 connectEventSocket 中的注释即可接入。
 *
 * 架构：HarmonyOS ArkUI 主应用 → Ark Web 容器 → Vue3 管理端
 *       WebSocket 用于接收设备实时感知事件、报警推送、设备心跳等。
 */

type EventMessageHandler = (data: unknown) => void

const handlers = new Set<EventMessageHandler>()
let ws: WebSocket | null = null

/** 连接事件 WebSocket（暂不连接） */
export function connectEventSocket(url?: string): void {
  // ---- 后端就绪后启用以下代码 ----
  // const target = url || 'ws://localhost:8080/ws/events'
  // ws = new WebSocket(target)
  // ws.onmessage = (event) => {
  //   try {
  //     const data = JSON.parse(event.data)
  //     handlers.forEach(fn => fn(data))
  //   } catch (e) {
  //     console.error('[WS] 消息解析失败', e)
  //   }
  // }
  // ws.onopen = () => console.log('[WS] 已连接:', target)
  // ws.onclose = () => console.log('[WS] 连接已关闭')
  // ws.onerror = (e) => console.error('[WS] 连接错误', e)
  console.log('[WebSocket] 接口已就绪，等待后端 WS63 模块接入')
}

/** 关闭 WebSocket 连接 */
export function closeSocket(): void {
  if (ws) {
    ws.close()
    ws = null
  }
  console.log('[WebSocket] 连接已关闭')
}

/** 订阅事件消息 — 返回取消订阅函数 */
export function onEventMessage(handler: EventMessageHandler): () => void {
  handlers.add(handler)
  return () => handlers.delete(handler)
}

/** 获取当前连接状态 */
export function isSocketConnected(): boolean {
  return ws !== null && ws.readyState === WebSocket.OPEN
}
