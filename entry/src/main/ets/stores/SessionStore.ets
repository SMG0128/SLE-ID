import {
  isSessionExpired,
  MobileSession
} from '../models/MobileSession'
import { TokenStore } from '../security/TokenStore'

export class SessionExpiredError extends Error {
  constructor() {
    super('Mobile session is missing or expired')
  }
}

export class SessionStore {
  private readonly tokenStore: TokenStore
  private session: MobileSession | null = null

  constructor(tokenStore: TokenStore) {
    this.tokenStore = tokenStore
  }

  async initialize(): Promise<void> {
    this.session = await this.tokenStore.load()
    if (this.session && isSessionExpired(this.session, Date.now())) {
      await this.clear()
    }
  }

  async accept(session: MobileSession): Promise<void> {
    if (session.accessToken.length === 0 ||
      isSessionExpired(session, Date.now())) {
      throw new SessionExpiredError()
    }
    await this.tokenStore.save(session)
    this.session = session
  }

  accessToken(): string {
    if (!this.session || isSessionExpired(this.session, Date.now())) {
      throw new SessionExpiredError()
    }
    return this.session.accessToken
  }

  hasUsableSession(): boolean {
    return this.session !== null &&
      !isSessionExpired(this.session, Date.now())
  }

  subjectId(): string {
    return this.session?.subjectId || ''
  }

  async clear(): Promise<void> {
    await this.tokenStore.clear()
    this.session = null
  }
}
