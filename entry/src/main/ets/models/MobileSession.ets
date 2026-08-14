export interface MobilePairRequest {
  pairingCode: string
  deviceId: string
  deviceName: string
}

export interface MobileSession {
  accessToken: string
  refreshToken: string
  expiresAt: string
  subjectId?: string
}

export function isSessionExpired(
  session: MobileSession,
  nowMillis: number
): boolean {
  const expiresAtMillis: number = Date.parse(session.expiresAt)
  if (!Number.isFinite(expiresAtMillis)) {
    return true
  }
  return expiresAtMillis <= nowMillis + 30000
}
