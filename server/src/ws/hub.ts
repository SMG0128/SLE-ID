import type { Server as HttpServer } from 'node:http'
import { WebSocket, WebSocketServer } from 'ws'
import { isAuthorized } from '../auth.js'
import type { MobileSessionStore } from '../services/mobileSessions.js'

export interface WsEnvelope<T = unknown> {
  version: 1
  seq: number
  topic: string
  sentAt: string
  data: T
}

export class WsHub {
  private readonly server: WebSocketServer
  private sequence = 0

  constructor(httpServer: HttpServer, apiToken: string | undefined, mobileSessions: MobileSessionStore) {
    this.server = new WebSocketServer({
      server: httpServer,
      verifyClient: ({ req }, done) => {
        const path = new URL(req.url || '/', 'http://localhost').pathname
        if (path === '/ws/events' && isAuthorized(req, apiToken)) done(true)
        else if (path === '/ws/mobile' && mobileSessions.resolveRequest(req)) done(true)
        else if (path !== '/ws/events' && path !== '/ws/mobile') done(false, 404, 'Not Found')
        else done(false, 401, 'Unauthorized')
      },
    })
    this.server.on('connection', (socket, request) => {
      const path = new URL(request.url || '/', 'http://localhost').pathname
      if (path === '/ws/events') {
        socket.send(JSON.stringify(this.envelope('server.ready', { connected: true })))
      }
    })
  }

  broadcast<T>(topic: string, data: T): WsEnvelope<T> {
    const message = this.envelope(topic, data)
    const encoded = JSON.stringify(message)
    for (const client of this.server.clients) {
      if (client.readyState === WebSocket.OPEN) client.send(encoded)
    }
    return message
  }

  /** Send a tablet-oriented envelope to /ws/mobile clients only. The tablet
   * router expects {type, subjectId, ...} rather than the admin {topic, data}
   * shape, so confirmation pushes must be translated before delivery. */
  broadcastMobile<T extends Record<string, unknown>>(
    type: string,
    subjectId: string,
    data: T,
  ): void {
    const message = { type, subjectId, ...data }
    const encoded = JSON.stringify(message)
    for (const client of this.server.clients) {
      if (client.readyState !== WebSocket.OPEN) continue
      const url = client.url || ''
      const path = url.startsWith('ws://') || url.startsWith('wss://') ?
        new URL(url).pathname : url
      if (path === '/ws/mobile') client.send(encoded)
    }
  }

  close(): Promise<void> {
    // A browser embedded in Ark Web may not complete the close handshake while
    // the app is shutting down. Terminate here so the HTTP server cannot hang.
    for (const client of this.server.clients) client.terminate()
    return new Promise(resolve => this.server.close(() => resolve()))
  }

  private envelope<T>(topic: string, data: T): WsEnvelope<T> {
    this.sequence += 1
    return { version: 1, seq: this.sequence, topic, sentAt: new Date().toISOString(), data }
  }
}
