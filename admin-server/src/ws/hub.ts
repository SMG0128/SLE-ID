import type { Server as HttpServer } from 'node:http'
import { WebSocket, WebSocketServer } from 'ws'
import { isAuthorized } from '../auth.js'

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

  constructor(httpServer: HttpServer, apiToken?: string) {
    this.server = new WebSocketServer({
      server: httpServer,
      path: '/ws/events',
      verifyClient: ({ req }, done) => {
        if (isAuthorized(req, apiToken)) done(true)
        else done(false, 401, 'Unauthorized')
      },
    })
    this.server.on('connection', socket => {
      socket.send(JSON.stringify(this.envelope('server.ready', { connected: true })))
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
