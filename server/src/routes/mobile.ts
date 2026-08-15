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

function mobileGrant(row: any) {
  const policies = row.policies ?? {}
  const usage = policies.usageLimit ?? {}
  const unlimited = usage.type === 'unlimited'
  const permissionId = String(row.hardware_permission_id)
  const organizationId = String(row.organization_id ?? 100)
  const policyVersion = String(row.policy_version)
  const cardAnonId = `CARD-${(Number(row.card_anon_id) >>> 0).toString(16).toUpperCase().padStart(8, '0')}`
  const syncState = {
    serverRevision: `${row.license_id}:${policyVersion}`,
    lastSyncAt: new Date().toISOString(),
    pendingOperations: [],
  }
  const preview = {
    permissionId,
    organizationId,
    issuerName: 'StarFollow',
    cardName: String(row.license_name),
    cardDescription: `${String(row.zone)} access permission`,
    permissionScope: Array.isArray(policies.scope) ? policies.scope : [String(row.zone)],
    validFrom: String(row.create_time),
    validUntil: String(row.expire_time),
    usageMode: unlimited ? 'unlimited' : 'limited',
    usageLimit: unlimited ? 0 : Number(usage.count ?? 0),
    adminConfirmRequired: policies.forceConfirm === true,
    policyVersion,
    phoneSubstituteAllowed: policies.huaweiFallback === true,
    alertPolicy: policies.unauthorizedAction === 'alarm' ? 'high_attention' : 'default',
    recordEvent: policies.recordEvent !== false,
    allowExecution: policies.allowExecute === true,
    alertOnUnauthorized: policies.unauthorizedAction === 'alarm',
    alertLevel: policies.unauthorizedAction === 'alarm' ? 'critical' : 'info',
    offlineAllowed: policies.offlineAllowed === true,
    directionDetection: policies.direction !== 'both',
    cardAppearance: 'access',
    category: 'access',
  }
  const digitalCardId = String(row.digital_card_id ?? '')
  const cardWritten = row.sync_status === 'synced'
  return {
    preview,
    authorization: {
      permissionId,
      digitalCardId,
      organizationId,
      name: String(row.license_name),
      issuer: 'StarFollow',
      status: 'active',
      scopes: preview.permissionScope,
      validFrom: preview.validFrom,
      validUntil: preview.validUntil,
      usageMode: preview.usageMode,
      usageLimit: preview.usageLimit,
      remainingUses: preview.usageLimit,
      adminConfirmRequired: preview.adminConfirmRequired,
      phoneSubstituteAllowed: preview.phoneSubstituteAllowed,
      alertPolicy: preview.alertPolicy,
      recordEvent: preview.recordEvent,
      allowExecution: preview.allowExecution,
      alertOnUnauthorized: preview.alertOnUnauthorized,
      alertLevel: preview.alertLevel,
      offlineAllowed: preview.offlineAllowed,
      directionDetection: preview.directionDetection,
      policyVersion,
      syncState,
    },
    digitalCard: digitalCardId ? {
      id: digitalCardId,
      name: String(row.license_name),
      issuer: 'StarFollow',
      cardAnonId,
      anonymousNumber: cardAnonId,
      nickname: '',
      detail: `${String(row.zone)} access permission`,
      category: 'access',
      status: 'active',
      visualStyle: 'access',
      permissionId,
      credentialId: cardWritten ? `credential-${permissionId}` : '',
      physicalCardId: cardWritten ? cardAnonId : '',
      credentialBindingStatus: cardWritten ? 'active' : 'notWritten',
      credentialCondition: 'active',
      adminConfirmRequired: preview.adminConfirmRequired,
      userConfirmationEnabled: preview.adminConfirmRequired,
      allowTemporaryPass: preview.phoneSubstituteAllowed,
      validFrom: preview.validFrom,
      validUntil: preview.validUntil,
      syncState,
    } : null,
  }
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

  router.use((req: Request, res: Response, next: NextFunction) => {
    const token = bearerToken(req)
    const session = sessions.resolveToken(token)
    if (!session) {
      throw new ApiError(401, 2503, 'Mobile session is invalid or expired')
    }
    res.locals.mobileSubjectId = session.subjectId
    next()
  })

  router.get('/cards', (_req, res) => {
    const grants = db.getMobileWallet(String(res.locals.mobileSubjectId)).map(row => mobileGrant(row))
    res.json({
      cards: grants.map(grant => grant.digitalCard).filter(Boolean),
      authorizations: grants.map(grant => grant.authorization),
      serverRevision: new Date().toISOString(),
    })
  })

  router.post('/invites/preview', (req, res) => {
    const code = requiredText(req.body?.code, 'code').toUpperCase()
    const invite = db.getMobileInvite(code) as any
    if (!invite || invite.expire_at <= new Date().toISOString() ||
      String(invite.revoke_reason || '').length > 0 ||
      invite.used_count >= invite.max_uses || invite.sync_status !== 'synced') {
      throw new ApiError(404, 2601, 'Invitation is invalid, expired, exhausted, or not deployed')
    }
    const grant = mobileGrant({ ...invite, card_anon_id: invite.target_card_anon_id })
    res.json({ preview: grant.preview })
  })

  router.post('/invites/redeem', (req, res) => {
    const code = requiredText(req.body?.code, 'code').toUpperCase()
    const invite = db.getMobileInvite(code) as any
    if (!invite) throw new ApiError(404, 2601, 'Invitation is not linked to a deployable permission')
    const binding = db.redeemMobileInvite(code, String(res.locals.mobileSubjectId)) as any
    if (!binding) throw new ApiError(409, 2602, 'Invitation cannot be redeemed')
    const row = db.getMobileWallet(String(res.locals.mobileSubjectId))
      .find(item => String(item.digital_card_id) === String(binding.cardId))
    if (!row) throw new ApiError(500, 5001, 'Redeemed card was not persisted')
    const grant = mobileGrant(row)
    const now = new Date().toISOString()
    res.json({
      result: {
        state: 'success',
        reason: 'none',
        operation: {
          operationId: `invite-redeem:${binding.inviteId}`,
          state: 'acknowledged',
          authority: 'backend',
          verificationRequired: false,
          receiptId: String(binding.bindingId),
          errorCode: '',
          updatedAt: now,
        },
        preview: grant.preview,
        authorization: grant.authorization,
        digitalCard: grant.digitalCard,
      },
    })
  })

  router.post('/cards/:id/write-package', (req, res) => {
    const cardId = requiredText(req.params.id, 'cardId')
    const writePackage = db.issueCardWritePackage(
      cardId,
      String(res.locals.mobileSubjectId),
    )
    if (!writePackage) {
      throw new ApiError(409, 2701, 'Card is not eligible for physical provisioning')
    }
    res.json({ writePackage })
  })

  router.post('/cards/:id/write-receipts', (req, res) => {
    const cardId = requiredText(req.params.id, 'cardId')
    const requestId = requiredText(req.body?.requestId, 'requestId')
    const physicalCardId = requiredText(req.body?.physicalCardId, 'physicalCardId')
    const credentialHash = requiredText(req.body?.credentialHash, 'credentialHash')
    const generation = Number(req.body?.generation)
    const acknowledgement = db.acknowledgeCardWrite(
      cardId,
      String(res.locals.mobileSubjectId),
      requestId,
      physicalCardId,
      credentialHash,
      generation,
    )
    if (!acknowledgement) {
      throw new ApiError(409, 2702, 'Card write receipt is invalid, expired, or mismatched')
    }
    res.json({ acknowledgement })
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
