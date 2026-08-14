import { Router } from 'express'
import type { StarFollowDatabase } from '../db.js'
import type { SerialConfigRecord } from '../domain.js'
import { ApiError, asyncRoute, ok } from '../http.js'
import type { HardwareService } from '../services/hardware.js'
import { GatewaySerial } from '../ws63/gateway.js'

function operatorOf(headers: Record<string, unknown>, body?: any): string {
  const header = headers['x-operator']
  return typeof header === 'string' && header.trim() ? header.trim() : String(body?.operator || '当前用户')
}

function requireString(value: unknown, name: string): string {
  if (typeof value !== 'string' || !value.trim()) throw new ApiError(400, 1001, `${name}不能为空`)
  return value.trim()
}

export function createApiRouter(db: StarFollowDatabase, hardware: HardwareService): Router {
  const router = Router()

  router.get('/health', (_req, res) => ok(res, {
    status: 'ok',
    time: new Date().toISOString(),
    serial: hardware.gateway.snapshot(),
  }))

  router.get('/capabilities', (_req, res) => ok(res, {
    protocol: 'SLE Protocol V2',
    hardware: {
      eventUpload: true,
      alertUpload: true,
      basicPolicyDeploy: true,
      adminConfirmation: true,
      commandRetry: true,
      remoteRestart: false,
      cardWriteThroughGateway: false,
      persistentOfflineQueue: false,
      fullTenFieldPolicy: false,
    },
  }))

  router.get('/events', (req, res) => ok(res, db.listEvents(req.query as Record<string, unknown>)))

  router.get('/alarms', (req, res) => ok(res, db.listAlarms(req.query as Record<string, unknown>)))
  router.post('/alarms/:id/handle', (req, res) => {
    const status = ['handled', 'ignored', 'escalated'].includes(req.body?.status) ? req.body.status : 'handled'
    if (!db.handleAlarm(req.params.id!, operatorOf(req.headers, req.body), status)) throw new ApiError(404, 1002, '报警不存在')
    ok(res, null)
  })

  router.get('/devices', (_req, res) => {
    const state = hardware.gateway.snapshot()
    const list = db.getDevices().map(device => ({
      ...device,
      usbConnected: Number(device.sourceId) === state.gatewaySourceId && state.connected,
    }))
    ok(res, { total: list.length, list })
  })
  router.get('/devices/ws63-status', (_req, res) => {
    const state = hardware.gateway.snapshot()
    ok(res, {
      protocol: 'SLE Protocol V2',
      band: '2.4GHz',
      nodes: db.getDevices().length,
      latency: null,
      status: state.connected && state.detectorBReady ? '正常' : '异常',
    })
  })
  router.get('/devices/serial-status', (_req, res) => ok(res, hardware.gateway.snapshot()))
  router.patch('/devices/:id', (req, res) => {
    const patch: { name?: string; location?: string; registered?: boolean } = {}
    if (req.body?.name !== undefined) patch.name = requireString(req.body.name, 'name')
    if (req.body?.location !== undefined) patch.location = requireString(req.body.location, 'location')
    if (req.body?.registered !== undefined) {
      if (typeof req.body.registered !== 'boolean') throw new ApiError(400, 1001, 'registered必须是布尔值')
      patch.registered = req.body.registered
    }
    if (Object.keys(patch).length === 0) throw new ApiError(400, 1001, '至少提供一个设备字段')
    const device = db.updateDevice(String(req.params.id), patch, operatorOf(req.headers, req.body))
    if (!device) throw new ApiError(404, 1002, '设备不存在或字段无效')
    ok(res, device)
  })
  router.post('/devices/:id/restart', (_req, _res) => {
    throw new ApiError(501, 3002, '当前硬件协议尚不支持远程重启；未发送任何串口命令')
  })

  router.get('/licenses', (_req, res) => ok(res, db.getLicenses()))
  router.post('/licenses', (req, res) => {
    requireString(req.body?.name, '许可名称')
    requireString(req.body?.zone, '区域')
    if (!req.body?.policies || typeof req.body.policies !== 'object') throw new ApiError(400, 1001, 'policies不能为空')
    ok(res, db.createLicense(req.body, operatorOf(req.headers, req.body)), '许可已保存；硬件同步需单独发布')
  })
  router.post('/licenses/:id/revoke', (req, res) => {
    if (!db.revokeLicense(req.params.id!, operatorOf(req.headers, req.body))) throw new ApiError(404, 1002, '许可不存在')
    ok(res, null, '许可已撤销并标记为待同步')
  })
  router.post('/licenses/:id/deploy', asyncRoute(async (req, res) => {
    const license = db.getLicense(String(req.params.id))
    if (!license) throw new ApiError(404, 1002, '许可不存在')
    const organizationId = Number(req.body?.organizationId ?? 100)
    if (!Number.isInteger(organizationId) || organizationId < 0 || organizationId > 0xffffffff) {
      throw new ApiError(400, 1001, 'organizationId必须是uint32')
    }
    ok(res, await hardware.deployPolicy(license, organizationId, operatorOf(req.headers, req.body)))
  }))

  router.get('/cards', (_req, res) => ok(res, db.getCards()))
  router.post('/cards/:cardId/actions', (req, res) => {
    const action = requireString(req.body?.action, 'action')
    const card = db.performCardAction(req.params.cardId!, action, operatorOf(req.headers, req.body))
    if (!card) throw new ApiError(404, 1002, '卡片不存在或操作不支持')
    ok(res, card, '卡片状态已保存为待同步；当前未向实体卡写入')
  })

  router.get('/invites', (_req, res) => ok(res, db.getInvites()))
  router.post('/invites', (req, res) => {
    requireString(req.body?.role, 'role')
    ok(res, db.createInvite(req.body, operatorOf(req.headers, req.body)))
  })
  router.post('/invites/:id/revoke', (req, res) => {
    const reason = requireString(req.body?.reason, 'reason')
    if (!db.revokeInvite(req.params.id!, reason, operatorOf(req.headers, req.body))) throw new ApiError(404, 1002, '邀请码不存在或已绑定')
    ok(res, null)
  })
  router.post('/invites/redeem', (req, res) => {
    const code = requireString(req.body?.code, 'code')
    const subject = requireString(req.body?.subject, 'subject')
    const binding = db.redeemInvite(code, subject, operatorOf(req.headers, req.body))
    if (!binding) throw new ApiError(409, 2401, '邀请码无效、已过期、已用尽或该对象已绑定')
    ok(res, binding, '邀请码已兑换并绑定')
  })

  router.get('/confirmations/pending', (_req, res) => ok(res, db.getPendingConfirmations()))
  router.post('/confirmations/:id/decision', asyncRoute(async (req, res) => {
    const decision = req.body?.decision
    if (decision !== 'approve' && decision !== 'reject') throw new ApiError(400, 1001, 'decision必须为approve或reject')
    ok(res, await hardware.decideConfirmation(String(req.params.id), decision, operatorOf(req.headers, req.body)))
  }))

  router.get('/system/settings', (_req, res) => ok(res, {
    serial: db.getSetting<SerialConfigRecord>('serial'),
    db: db.databaseInfo(),
    serverSyncEnabled: db.getSetting<boolean>('serverSyncEnabled') ?? false,
    adminName: db.getSetting<string>('adminName') ?? 'admin',
    adminSecret: '******',
  }))
  router.get('/audit-logs', (req, res) => ok(res, db.listAuditLogs(req.query as Record<string, unknown>)))
  router.post('/system/backup', asyncRoute(async (req, res) => {
    ok(res, await db.createBackup(operatorOf(req.headers, req.body)))
  }))
  router.get('/system/serial-ports', asyncRoute(async (_req, res) => ok(res, await GatewaySerial.listPorts())))
  router.patch('/system/serial', asyncRoute(async (req, res) => {
    const current = db.getSetting<SerialConfigRecord>('serial') ?? { port: '', baudRate: 115200, autoReconnect: true }
    const config: SerialConfigRecord = {
      port: req.body?.port === undefined ? current.port : String(req.body.port).trim(),
      baudRate: req.body?.baudRate === undefined ? current.baudRate : Number(req.body.baudRate),
      autoReconnect: req.body?.autoReconnect === undefined ? current.autoReconnect : Boolean(req.body.autoReconnect),
    }
    if (config.baudRate !== 115200) throw new ApiError(400, 1001, 'Detector B 固定使用115200波特率')
    await hardware.gateway.configure(config, Boolean(config.port))
    db.setSetting('serial', config)
    db.recordAudit('system.serial.update', 'serial', config.port || 'disconnected', operatorOf(req.headers, req.body), { before: current, after: config })
    ok(res, config)
  }))
  router.patch('/system/server-sync', (req, res) => {
    if (typeof req.body?.enabled !== 'boolean') throw new ApiError(400, 1001, 'enabled必须是布尔值')
    const before = db.getSetting<boolean>('serverSyncEnabled') ?? false
    db.setSetting('serverSyncEnabled', req.body.enabled)
    db.recordAudit('system.server-sync.update', 'setting', 'serverSyncEnabled', operatorOf(req.headers, req.body), { before, after: req.body.enabled })
    ok(res, null)
  })

  return router
}
