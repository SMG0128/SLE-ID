import { Router, type NextFunction, type Request, type Response } from 'express'
import type { AppConfig } from '../config.js'
import type { StarFollowDatabase } from '../db.js'
import { ApiError } from '../http.js'
import type { HardwareService } from '../services/hardware.js'
import type { MobileSessionStore } from '../services/mobileSessions.js'

function requiredText(value: unknown, name: string): string {
  if (typeof value !== 'string' || !value.trim()) {
    throw new ApiError(400, 1001, `${name} must not be empty`)
  }
  return value.trim()
}

function bearerToken(request: Request): string | null {
  const match = /^Bearer\s+(.+)$/i.exec(String(request.headers.authorization || '').trim())
  return match?.[1]?.trim() || null
}

export function createMobileRouter(
  config: AppConfig,
  db: StarFollowDatabase,
  hardware: HardwareService,
  sessions: MobileSessionStore,
): Router {
  const router = Router()

  router.get('/health', (_req, res) => {
    res.json({ status: 'ok', time: new Date().toISOString(), serial: hardware.gateway.snapshot() })
  })

  router.post('/pair', (req, res) => {
    const expectedCode = config.mobilePairingCode?.trim()
    if (!expectedCode) throw new ApiError(503, 2501, 'Mobile pairing is not enabled')

    const pairingCode = requiredText(req.body?.pairingCode, 'pairingCode')
    const deviceId = requiredText(req.body?.deviceId, 'deviceId')
    const deviceName = requiredText(req.body?.deviceName, 'deviceName')
    if (pairingCode !== expectedCode) throw new ApiError(401, 2502, 'Invalid mobile pairing code')

    const subjectId = `mobile:${deviceId}`
    const session = sessions.create(subjectId)
    db.recordAudit('mobile.pair', 'mobile', subjectId, deviceName, { deviceId })
    res.json({ session })
  })

  router.use((req: Request, _res: Response, next: NextFunction) => {
    const token = bearerToken(req)
    if (!sessions.resolveToken(token)) {
      throw new ApiError(401, 2503, 'Mobile session is invalid or expired')
    }
    next()
  })

  router.get('/cards', (_req, res) => {
    res.json({ cards: [], authorizations: [], serverRevision: new Date().toISOString() })
  })

  router.get('/confirmations/pending', (_req, res) => {
    const snapshot = hardware.gateway.snapshot()
    const confirmations = db.getPendingConfirmations().map((item: any) => ({
      requestId: String(item.id),
      digitalCardId: String(item.cardId || ''),
      permissionId: String(item.permissionId ?? ''),
      detectorId: snapshot.gatewaySourceId === null ? '' :
        `DEV-${Number(snapshot.gatewaySourceId).toString(16).padStart(8, '0').toUpperCase()}`,
      checkpointName: 'Detector B',
      eventId: String(item.eventKey || item.eventId || ''),
      action: 'passage',
      direction: 'unknown',
      randomCode: String(item.requestId ?? '').slice(-6).padStart(6, '0'),
      adminConfirmRequired: true,
      status: 'pending',
      createdAt: String(item.receivedAt || ''),
      expiresAt: String(item.expiresAt || ''),
      resolvedAt: '',
    }))
    res.json({ confirmations })
  })

  return router
}
