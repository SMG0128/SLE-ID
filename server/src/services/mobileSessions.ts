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

export interface MobileSessionPersistence {
  saveMobileSession(session: { accessToken: string; refreshToken: string; subjectId: string; expiresAt: string }): void
  loadMobileSessions(): Array<{ accessToken: string; refreshToken: string; subjectId: string; expiresAt: string }>
  deleteMobileSession(accessToken: string): void
}

export class MobileSessionStore {
  private readonly sessions = new Map<string, MobileSessionRecord>()
  private readonly persistence: MobileSessionPersistence | null

  constructor(persistence: MobileSessionPersistence | null = null) {
    this.persistence = persistence
    if (persistence) {
      const now = new Date().toISOString()
      for (const stored of persistence.loadMobileSessions()) {
        if (stored.expiresAt > now) {
          this.sessions.set(stored.accessToken, { subjectId: stored.subjectId, expiresAt: stored.expiresAt })
        } else {
          persistence.deleteMobileSession(stored.accessToken)
        }
      }
    }
  }

  create(subjectId: string): CreatedMobileSession {
    const accessToken = randomBytes(32).toString('base64url')
    const refreshToken = randomBytes(32).toString('base64url')
    const expiresAt = new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString()
    this.sessions.set(accessToken, { subjectId, expiresAt })
    if (this.persistence) {
      this.persistence.saveMobileSession({ accessToken, refreshToken, subjectId, expiresAt })
    }
    return { accessToken, refreshToken, expiresAt, subjectId }
  }

  resolveToken(token: string | null): MobileSessionRecord | null {
    if (!token) return null
    const session = this.sessions.get(token)
    if (!session || session.expiresAt <= new Date().toISOString()) {
      this.sessions.delete(token)
      if (this.persistence && session) this.persistence.deleteMobileSession(token)
      return null
    }
    return session
  }

  resolveRequest(request: IncomingMessage): MobileSessionRecord | null {
    return this.resolveToken(requestToken(request))
  }
}
