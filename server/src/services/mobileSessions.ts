import { randomBytes } from 'node:crypto'
import type { IncomingMessage } from 'node:http'
import { requestToken } from '../auth.js'

export interface MobileSessionRecord {
  subjectId: string
  expiresAt: string
}

export interface CreatedMobileSession extends MobileSessionRecord {
  accessToken: string
  refreshToken: string
}

export class MobileSessionStore {
  private readonly sessions = new Map<string, MobileSessionRecord>()

  create(subjectId: string): CreatedMobileSession {
    const accessToken = randomBytes(32).toString('base64url')
    const refreshToken = randomBytes(32).toString('base64url')
    const expiresAt = new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString()
    this.sessions.set(accessToken, { subjectId, expiresAt })
    return { accessToken, refreshToken, expiresAt, subjectId }
  }

  resolveToken(token: string | null): MobileSessionRecord | null {
    if (!token) return null
    const session = this.sessions.get(token)
    if (!session || session.expiresAt <= new Date().toISOString()) {
      this.sessions.delete(token)
      return null
    }
    return session
  }

  resolveRequest(request: IncomingMessage): MobileSessionRecord | null {
    return this.resolveToken(requestToken(request))
  }
}
