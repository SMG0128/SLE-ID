import fs from 'node:fs'
import path from 'node:path'
import { randomBytes, randomUUID } from 'node:crypto'
import BetterSqlite3 from 'better-sqlite3'
import type {
  AlarmLevel,
  AlarmType,
  HardwareAlarm,
  HardwareConfirmation,
  HardwareEvent,
  HardwareHeartbeat,
  SerialConfigRecord,
} from './domain.js'
import { formatCardId, formatDeviceId, formatFirmware } from './domain.js'

type Database = BetterSqlite3.Database

export interface IngestResult<T> {
  duplicateFrame: boolean
  value: T | null
}

export class StarFollowDatabase {
  readonly raw: Database

  constructor(databasePath: string) {
    fs.mkdirSync(path.dirname(databasePath), { recursive: true })
    this.raw = new BetterSqlite3(databasePath)
    this.raw.pragma('journal_mode = WAL')
    this.raw.pragma('foreign_keys = ON')
    this.raw.pragma('busy_timeout = 5000')
    this.raw.pragma('synchronous = FULL')
    this.migrate()
    this.ensureDefaults()
  }

  close(): void {
    this.raw.close()
  }

  private migrate(): void {
    this.raw.exec(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS devices (
        source_id INTEGER PRIMARY KEY,
        role INTEGER NOT NULL,
        name TEXT NOT NULL,
        location TEXT NOT NULL DEFAULT '未配置',
        firmware TEXT NOT NULL DEFAULT '-',
        policy_version INTEGER NOT NULL DEFAULT 0,
        last_boot_id INTEGER NOT NULL DEFAULT 0,
        last_seen_at TEXT,
        uptime_ms INTEGER NOT NULL DEFAULT 0,
        queue_depth INTEGER NOT NULL DEFAULT 0,
        queue_overflows INTEGER NOT NULL DEFAULT 0,
        frames_sent INTEGER NOT NULL DEFAULT 0,
        registered INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE IF NOT EXISTS device_sessions (
        source_id INTEGER NOT NULL,
        boot_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        last_uptime_ms INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (source_id, boot_id)
      );

      CREATE TABLE IF NOT EXISTS hardware_frames (
        source_id INTEGER NOT NULL,
        boot_id INTEGER NOT NULL,
        message_id INTEGER NOT NULL,
        message_type INTEGER NOT NULL,
        received_at TEXT NOT NULL,
        PRIMARY KEY (source_id, boot_id, message_id)
      );

      CREATE TABLE IF NOT EXISTS events (
        event_key TEXT PRIMARY KEY,
        event_id INTEGER NOT NULL,
        source_id INTEGER NOT NULL,
        boot_id INTEGER NOT NULL,
        card_anon_id INTEGER NOT NULL,
        permission_id INTEGER NOT NULL,
        device_timestamp_ms INTEGER NOT NULL,
        decision_timestamp_ms INTEGER NOT NULL,
        direction INTEGER NOT NULL,
        auth INTEGER NOT NULL,
        action INTEGER NOT NULL,
        confirm INTEGER NOT NULL,
        execution INTEGER NOT NULL,
        reason INTEGER NOT NULL,
        distance_cm INTEGER NOT NULL,
        confidence INTEGER NOT NULL,
        state INTEGER NOT NULL,
        result TEXT NOT NULL,
        status TEXT NOT NULL,
        received_at TEXT NOT NULL,
        UNIQUE (source_id, boot_id, event_id)
      );
      CREATE INDEX IF NOT EXISTS idx_events_received_at ON events(received_at DESC);
      CREATE INDEX IF NOT EXISTS idx_events_card ON events(card_anon_id, received_at DESC);

      CREATE TABLE IF NOT EXISTS alarms (
        id TEXT PRIMARY KEY,
        event_key TEXT NOT NULL,
        type TEXT NOT NULL,
        level TEXT NOT NULL,
        message TEXT NOT NULL,
        solution TEXT NOT NULL,
        operator TEXT NOT NULL DEFAULT '',
        handle_status TEXT NOT NULL DEFAULT 'unhandled',
        handled_at TEXT,
        created_at TEXT NOT NULL,
        UNIQUE (event_key, type),
        FOREIGN KEY (event_key) REFERENCES events(event_key)
      );
      CREATE INDEX IF NOT EXISTS idx_alarms_created_at ON alarms(created_at DESC);

      CREATE TABLE IF NOT EXISTS confirmations (
        id TEXT PRIMARY KEY,
        gateway_source_id INTEGER NOT NULL,
        gateway_boot_id INTEGER NOT NULL,
        request_id INTEGER NOT NULL,
        event_id INTEGER NOT NULL,
        event_key TEXT,
        card_anon_id INTEGER NOT NULL,
        permission_id INTEGER NOT NULL,
        device_timestamp_ms INTEGER NOT NULL,
        action INTEGER NOT NULL,
        direction INTEGER NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending',
        decision TEXT,
        expires_at TEXT NOT NULL,
        received_at TEXT NOT NULL,
        resolved_at TEXT,
        UNIQUE (gateway_source_id, gateway_boot_id, request_id)
      );

      CREATE TABLE IF NOT EXISTS licenses (
        id TEXT PRIMARY KEY,
        hardware_permission_id INTEGER NOT NULL UNIQUE,
        name TEXT NOT NULL,
        zone TEXT NOT NULL,
        status TEXT NOT NULL,
        card_count INTEGER NOT NULL DEFAULT 0,
        policies_json TEXT NOT NULL,
        key_version INTEGER NOT NULL DEFAULT 1,
        policy_version INTEGER NOT NULL DEFAULT 1,
        capability_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'saved',
        last_sync TEXT NOT NULL DEFAULT '',
        creator TEXT NOT NULL,
        create_time TEXT NOT NULL,
        expire_time TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS cards (
        id TEXT PRIMARY KEY,
        card_anon_id INTEGER NOT NULL UNIQUE,
        owner TEXT NOT NULL,
        license_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '正常',
        key_version INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'pending_sync',
        last_sync TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (license_id) REFERENCES licenses(id)
      );

      CREATE TABLE IF NOT EXISTS invites (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL,
        status TEXT NOT NULL,
        used_by TEXT NOT NULL DEFAULT '',
        used_at TEXT,
        expire_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        revoke_reason TEXT NOT NULL DEFAULT '',
        one_time INTEGER NOT NULL DEFAULT 1,
        max_uses INTEGER NOT NULL DEFAULT 1
      );

      CREATE TABLE IF NOT EXISTS device_commands (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id INTEGER NOT NULL,
        command_type INTEGER NOT NULL,
        payload_hash TEXT NOT NULL,
        target_source_id INTEGER,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        result_code INTEGER,
        result_value INTEGER,
        error TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT
      );

      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        object_type TEXT NOT NULL,
        object_id TEXT NOT NULL,
        operator TEXT NOT NULL,
        detail_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      );

      INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES (1, datetime('now'));
    `)
    this.migrateCommandHistoryV2()
    this.migrateInviteBindingsV3()
    this.raw.exec(`
      CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_commands_created_at ON device_commands(created_at DESC);
    `)
  }

  private migrateCommandHistoryV2(): void {
    const applied = this.raw.prepare('SELECT 1 FROM schema_migrations WHERE version=2').get()
    if (applied) return
    this.raw.transaction(() => {
      const row = this.raw.prepare("SELECT sql FROM sqlite_master WHERE type='table' AND name='device_commands'").get() as { sql: string } | undefined
      if (row?.sql.includes('UNIQUE (request_id, command_type)')) {
        this.raw.exec(`
          ALTER TABLE device_commands RENAME TO device_commands_v1;
          CREATE TABLE device_commands (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            request_id INTEGER NOT NULL,
            command_type INTEGER NOT NULL,
            payload_hash TEXT NOT NULL,
            target_source_id INTEGER,
            status TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            result_code INTEGER,
            result_value INTEGER,
            error TEXT,
            created_at TEXT NOT NULL,
            completed_at TEXT
          );
          INSERT INTO device_commands SELECT * FROM device_commands_v1;
          DROP TABLE device_commands_v1;
        `)
      }
      this.raw.prepare("INSERT INTO schema_migrations(version, applied_at) VALUES (2, datetime('now'))").run()
    })()
  }

  private migrateInviteBindingsV3(): void {
    const applied = this.raw.prepare('SELECT 1 FROM schema_migrations WHERE version=3').get()
    if (applied) return
    this.raw.transaction(() => {
      const columns = this.raw.prepare('PRAGMA table_info(invites)').all() as Array<{ name: string }>
      if (!columns.some(column => column.name === 'used_count')) {
        this.raw.exec('ALTER TABLE invites ADD COLUMN used_count INTEGER NOT NULL DEFAULT 0')
      }
      this.raw.exec(`
        CREATE TABLE IF NOT EXISTS invite_bindings (
          id TEXT PRIMARY KEY,
          invite_id TEXT NOT NULL,
          subject TEXT NOT NULL,
          bound_at TEXT NOT NULL,
          UNIQUE (invite_id, subject),
          FOREIGN KEY (invite_id) REFERENCES invites(id)
        );
        CREATE INDEX IF NOT EXISTS idx_invite_bindings_invite ON invite_bindings(invite_id, bound_at);
        UPDATE invites SET used_count=max_uses WHERE status='已绑定' AND used_count=0;
        UPDATE invites SET one_time=CASE WHEN max_uses<=1 THEN 1 ELSE 0 END;
      `)
      this.raw.prepare("INSERT INTO schema_migrations(version, applied_at) VALUES (3, datetime('now'))").run()
    })()
  }

  private ensureDefaults(): void {
    if (this.getSetting<SerialConfigRecord>('serial') === null) {
      this.setSetting('serial', { port: '', baudRate: 115200, autoReconnect: true })
    }
    if (this.getSetting<boolean>('serverSyncEnabled') === null) this.setSetting('serverSyncEnabled', false)
    if (this.getSetting<string>('adminName') === null) this.setSetting('adminName', 'admin')
    if (this.getSetting<number>('nextRequestId') === null) this.setSetting('nextRequestId', 1)
    if (this.getSetting<number>('nextPolicyVersion') === null) this.setSetting('nextPolicyVersion', 1)
  }

  getSetting<T>(key: string): T | null {
    const row = this.raw.prepare('SELECT value_json FROM app_settings WHERE key = ?').get(key) as { value_json: string } | undefined
    return row ? JSON.parse(row.value_json) as T : null
  }

  setSetting<T>(key: string, value: T): void {
    this.raw.prepare(`
      INSERT INTO app_settings(key, value_json, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json, updated_at=excluded.updated_at
    `).run(key, JSON.stringify(value), new Date().toISOString())
  }

  nextRequestId(): number {
    return this.raw.transaction(() => {
      const current = this.getSetting<number>('nextRequestId') ?? 1
      const value = current === 0 ? 1 : current >>> 0
      const next = value === 0xffffffff ? 1 : value + 1
      this.setSetting('nextRequestId', next)
      return value
    })()
  }

  nextPolicyVersion(): number {
    return this.raw.transaction(() => {
      const current = this.getSetting<number>('nextPolicyVersion') ?? 1
      const value = current === 0 ? 1 : current >>> 0
      const next = value === 0xffffffff ? 1 : value + 1
      this.setSetting('nextPolicyVersion', next)
      return value
    })()
  }

  upsertHeartbeat(heartbeat: HardwareHeartbeat): void {
    this.raw.transaction(() => {
      this.raw.prepare(`
        INSERT INTO devices(source_id, role, name, firmware, policy_version, last_boot_id, last_seen_at,
          uptime_ms, queue_depth, queue_overflows, frames_sent)
        VALUES (?, 3, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(source_id) DO UPDATE SET role=3, firmware=excluded.firmware,
          policy_version=excluded.policy_version, last_boot_id=excluded.last_boot_id,
          last_seen_at=excluded.last_seen_at, uptime_ms=excluded.uptime_ms,
          queue_depth=excluded.queue_depth, queue_overflows=excluded.queue_overflows,
          frames_sent=excluded.frames_sent
      `).run(
        heartbeat.gatewaySourceId,
        formatDeviceId(heartbeat.gatewaySourceId),
        formatFirmware(heartbeat.firmwareVersion),
        heartbeat.policyVersion,
        heartbeat.gatewayBootId,
        heartbeat.receivedAt,
        heartbeat.uptimeMs,
        heartbeat.queueDepth,
        heartbeat.queueOverflows,
        heartbeat.framesSent,
      )
      this.raw.prepare(`
        INSERT INTO device_sessions(source_id, boot_id, started_at, last_seen_at, last_uptime_ms)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(source_id, boot_id) DO UPDATE SET last_seen_at=excluded.last_seen_at,
          last_uptime_ms=excluded.last_uptime_ms
      `).run(heartbeat.gatewaySourceId, heartbeat.gatewayBootId, heartbeat.receivedAt, heartbeat.receivedAt, heartbeat.uptimeMs)
    })()
  }

  ingestEventFrame(
    frameIdentity: { sourceId: number; bootId: number; messageId: number; type: number; receivedAt: string },
    event: HardwareEvent,
    alarm: HardwareAlarm | null,
  ): IngestResult<{ event: HardwareEvent; alarmId: string | null }> {
    return this.raw.transaction(() => {
      if (!this.recordFrame(frameIdentity)) return { duplicateFrame: true, value: null }
      this.raw.prepare(`
        INSERT INTO devices(source_id, role, name, last_boot_id, last_seen_at)
        VALUES (?, 2, ?, ?, ?)
        ON CONFLICT(source_id) DO UPDATE SET role=2, last_boot_id=excluded.last_boot_id,
          last_seen_at=excluded.last_seen_at
      `).run(event.sourceId, formatDeviceId(event.sourceId), event.bootId, event.receivedAt)
      this.raw.prepare(`
        INSERT INTO device_sessions(source_id, boot_id, started_at, last_seen_at, last_uptime_ms)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(source_id, boot_id) DO UPDATE SET last_seen_at=excluded.last_seen_at,
          last_uptime_ms=excluded.last_uptime_ms
      `).run(event.sourceId, event.bootId, event.receivedAt, event.receivedAt, event.timestampMs)
      this.raw.prepare(`
        INSERT INTO events(event_key, event_id, source_id, boot_id, card_anon_id, permission_id,
          device_timestamp_ms, decision_timestamp_ms, direction, auth, action, confirm, execution,
          reason, distance_cm, confidence, state, result, status, received_at)
        VALUES (@eventKey, @eventId, @sourceId, @bootId, @cardAnonId, @permissionId,
          @timestampMs, @decisionTimestampMs, @direction, @auth, @action, @confirm, @execution,
          @reason, @distanceCm, @confidence, @state, @result, @status, @receivedAt)
        ON CONFLICT(event_key) DO UPDATE SET auth=excluded.auth, action=excluded.action,
          confirm=excluded.confirm, execution=excluded.execution, reason=excluded.reason,
          result=excluded.result, status=excluded.status, decision_timestamp_ms=excluded.decision_timestamp_ms
      `).run(event)
      let alarmId: string | null = null
      if (alarm) {
        alarmId = `AL-${randomUUID()}`
        const result = this.raw.prepare(`
          INSERT OR IGNORE INTO alarms(id, event_key, type, level, message, solution, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run(alarmId, event.eventKey, alarm.type, alarm.level, alarm.message, alarm.solution, event.receivedAt)
        if (result.changes === 0) {
          const existing = this.raw.prepare('SELECT id FROM alarms WHERE event_key=? AND type=?').get(event.eventKey, alarm.type) as { id: string }
          alarmId = existing.id
        }
      }
      return { duplicateFrame: false, value: { event, alarmId } }
    })()
  }

  ingestConfirmationFrame(
    frameIdentity: { sourceId: number; bootId: number; messageId: number; type: number; receivedAt: string },
    confirmation: HardwareConfirmation,
  ): IngestResult<Record<string, unknown>> {
    return this.raw.transaction(() => {
      if (!this.recordFrame(frameIdentity)) return { duplicateFrame: true, value: null }
      const event = this.raw.prepare(`
        SELECT event_key FROM events WHERE event_id=? AND card_anon_id=? AND permission_id=?
        ORDER BY received_at DESC LIMIT 1
      `).get(confirmation.eventId, confirmation.cardAnonId, confirmation.permissionId) as { event_key: string } | undefined
      const id = `CF-${confirmation.gatewaySourceId.toString(16).toUpperCase()}-${confirmation.gatewayBootId.toString(16).toUpperCase()}-${confirmation.requestId}`
      this.raw.prepare(`
        INSERT INTO confirmations(id, gateway_source_id, gateway_boot_id, request_id, event_id,
          event_key, card_anon_id, permission_id, device_timestamp_ms, action, direction,
          expires_at, received_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        id, confirmation.gatewaySourceId, confirmation.gatewayBootId, confirmation.requestId,
        confirmation.eventId, event?.event_key ?? null, confirmation.cardAnonId,
        confirmation.permissionId, confirmation.deviceTimestampMs, confirmation.action,
        confirmation.direction, confirmation.expiresAt, confirmation.receivedAt,
      )
      return {
        duplicateFrame: false,
        value: {
          id,
          requestId: confirmation.requestId,
          eventId: confirmation.eventId,
          eventKey: event?.event_key ?? null,
          cardId: formatCardId(confirmation.cardAnonId),
          permissionId: confirmation.permissionId,
          state: 'pending',
          expiresAt: confirmation.expiresAt,
        },
      }
    })()
  }

  private recordFrame(frame: { sourceId: number; bootId: number; messageId: number; type: number; receivedAt: string }): boolean {
    const result = this.raw.prepare(`
      INSERT OR IGNORE INTO hardware_frames(source_id, boot_id, message_id, message_type, received_at)
      VALUES (?, ?, ?, ?, ?)
    `).run(frame.sourceId, frame.bootId, frame.messageId, frame.type, frame.receivedAt)
    return result.changes === 1
  }

  getDevices(): Array<Record<string, unknown>> {
    const now = Date.now()
    const rows = this.raw.prepare('SELECT * FROM devices ORDER BY role DESC, source_id').all() as Array<Record<string, unknown>>
    return rows.map(row => {
      const lastSeen = typeof row.last_seen_at === 'string' ? Date.parse(row.last_seen_at) : 0
      const role = Number(row.role)
      const onlineWindow = role === 3 ? 3500 : 15000
      const online = lastSeen > 0 && now - lastSeen <= onlineWindow
      const uptimeMs = Number(row.uptime_ms || 0)
      return {
        id: formatDeviceId(Number(row.source_id)),
        name: row.name,
        location: row.location,
        status: online ? '在线' : '离线',
        firmware: row.firmware,
        heartbeat: lastSeen > 0 ? Math.max(0, Math.floor((now - lastSeen) / 1000)) : 0,
        usbConnected: false,
        policyVersion: `POL-${Number(row.policy_version)}`,
        uptime: online && uptimeMs > 0 ? formatUptime(uptimeMs) : '-',
        role: role === 3 ? 'gateway' : 'detector',
        sourceId: Number(row.source_id),
        queueDepth: Number(row.queue_depth),
        queueOverflows: Number(row.queue_overflows),
        registered: Number(row.registered) === 1,
      }
    })
  }

  updateDevice(id: string, patch: { name?: string; location?: string; registered?: boolean }, operator: string): Record<string, unknown> | null {
    const match = /^DEV-([0-9A-Fa-f]{8})$/.exec(id)
    if (!match) return null
    const sourceId = Number.parseInt(match[1]!, 16) >>> 0
    const before = this.raw.prepare('SELECT name, location, registered FROM devices WHERE source_id=?').get(sourceId) as Record<string, unknown> | undefined
    if (!before) return null
    const name = patch.name === undefined ? String(before.name) : patch.name.trim()
    const location = patch.location === undefined ? String(before.location) : patch.location.trim()
    const registered = patch.registered === undefined ? Number(before.registered) : (patch.registered ? 1 : 0)
    if (!name || !location) return null
    this.raw.prepare('UPDATE devices SET name=?, location=?, registered=? WHERE source_id=?').run(name, location, registered, sourceId)
    this.recordAudit('device.update', 'device', id, operator, { before, after: { name, location, registered: registered === 1 } })
    return this.getDevices().find(device => device.id === id) ?? null
  }

  listEvents(query: Record<string, unknown>): { total: number; list: Array<Record<string, unknown>> } {
    const clauses: string[] = []
    const params: Record<string, unknown> = {}
    if (query.device) { clauses.push('(d.name LIKE @device OR printf(\'DEV-%08X\', e.source_id) LIKE @device)'); params.device = `%${query.device}%` }
    if (query.cardId) { clauses.push("printf('CARD-%08X', e.card_anon_id) LIKE @cardId"); params.cardId = `%${query.cardId}%` }
    if (query.owner) { clauses.push('c.owner LIKE @owner'); params.owner = `%${query.owner}%` }
    if (query.result) { clauses.push('e.result = @result'); params.result = query.result }
    if (query.dateStart) { clauses.push('e.received_at >= @dateStart'); params.dateStart = `${query.dateStart}T00:00:00.000Z` }
    if (query.dateEnd) { clauses.push('e.received_at <= @dateEnd'); params.dateEnd = `${query.dateEnd}T23:59:59.999Z` }
    const where = clauses.length > 0 ? `WHERE ${clauses.join(' AND ')}` : ''
    const page = Math.max(1, Number(query.page) || 1)
    const pageSize = Math.min(200, Math.max(1, Number(query.pageSize) || 20))
    params.limit = pageSize
    params.offset = (page - 1) * pageSize
    const from = `FROM events e LEFT JOIN devices d ON d.source_id=e.source_id LEFT JOIN cards c ON c.card_anon_id=e.card_anon_id ${where}`
    const total = Number((this.raw.prepare(`SELECT COUNT(*) AS value ${from}`).get(params) as { value: number }).value)
    const rows = this.raw.prepare(`
      SELECT e.*, COALESCE(d.name, printf('DEV-%08X', e.source_id)) AS device_name,
        COALESCE(c.owner, '') AS owner_name
      ${from} ORDER BY e.received_at DESC LIMIT @limit OFFSET @offset
    `).all(params) as Array<Record<string, unknown>>
    return {
      total,
      list: rows.map(row => {
        const received = new Date(String(row.received_at))
        return {
          eventId: row.event_key,
          time: received.toLocaleTimeString('zh-CN', { hour12: false }),
          dateStr: received.toLocaleDateString('zh-CN'),
          device: row.device_name,
          cardId: formatCardId(Number(row.card_anon_id)),
          owner: row.owner_name,
          result: row.result,
          status: row.status,
        }
      }),
    }
  }

  listAlarms(query: Record<string, unknown>): Record<string, unknown> {
    const clauses: string[] = []
    const params: Record<string, unknown> = {}
    for (const key of ['level', 'type', 'handleStatus'] as const) {
      const dbKey = key === 'handleStatus' ? 'handle_status' : key
      if (query[key]) { clauses.push(`a.${dbKey}=@${key}`); params[key] = query[key] }
    }
    const where = clauses.length > 0 ? `WHERE ${clauses.join(' AND ')}` : ''
    const page = Math.max(1, Number(query.page) || 1)
    const pageSize = Math.min(200, Math.max(1, Number(query.pageSize) || 20))
    params.limit = pageSize
    params.offset = (page - 1) * pageSize
    const total = Number((this.raw.prepare(`SELECT COUNT(*) AS value FROM alarms a ${where}`).get(params) as { value: number }).value)
    const rows = this.raw.prepare(`
      SELECT a.*, e.card_anon_id, e.source_id, COALESCE(d.name, printf('DEV-%08X', e.source_id)) AS device_name
      FROM alarms a JOIN events e ON e.event_key=a.event_key
      LEFT JOIN devices d ON d.source_id=e.source_id ${where}
      ORDER BY a.created_at DESC LIMIT @limit OFFSET @offset
    `).all(params) as Array<Record<string, unknown>>
    const statsRows = this.raw.prepare('SELECT level, handle_status, COUNT(*) AS count FROM alarms GROUP BY level, handle_status').all() as Array<{ level: AlarmLevel; handle_status: string; count: number }>
    const stats = { severe: 0, high: 0, normal: 0, total: 0, unhandled: 0 }
    for (const row of statsRows) {
      stats[row.level] += row.count
      stats.total += row.count
      if (row.handle_status === 'unhandled') stats.unhandled += row.count
    }
    return {
      stats,
      total,
      list: rows.map(row => ({
        id: row.id,
        level: row.level,
        type: row.type,
        device: row.device_name,
        cardId: formatCardId(Number(row.card_anon_id)),
        message: row.message,
        operator: row.operator,
        time: new Date(String(row.created_at)).toLocaleString('zh-CN', { hour12: false }),
        handleStatus: row.handle_status,
        solution: row.solution,
      })),
    }
  }

  handleAlarm(id: string, operator: string, status = 'handled'): boolean {
    const result = this.raw.prepare(`
      UPDATE alarms SET handle_status=?, operator=?, handled_at=? WHERE id=?
    `).run(status, operator, new Date().toISOString(), id)
    if (result.changes > 0) this.audit('alarm.handle', 'alarm', id, operator, { status })
    return result.changes > 0
  }

  getPendingConfirmations(): Array<Record<string, unknown>> {
    const now = new Date().toISOString()
    this.raw.prepare("UPDATE confirmations SET state='expired', resolved_at=? WHERE state='pending' AND expires_at<=?").run(now, now)
    return this.raw.prepare(`
      SELECT id, request_id, event_id, event_key, card_anon_id, permission_id, expires_at, received_at
      FROM confirmations WHERE state='pending' AND expires_at>? ORDER BY received_at
    `).all(now).map((row: any) => ({
      id: row.id,
      requestId: row.request_id,
      eventId: row.event_id,
      eventKey: row.event_key,
      cardId: formatCardId(row.card_anon_id),
      permissionId: row.permission_id,
      state: 'pending',
      expiresAt: row.expires_at,
      receivedAt: row.received_at,
    }))
  }

  recoverInterruptedConfirmations(): { requeued: number; expired: number } {
    return this.raw.transaction(() => {
      const now = new Date().toISOString()
      const expired = this.raw.prepare(`
        UPDATE confirmations SET state='expired', resolved_at=?
        WHERE state IN ('pending', 'sending') AND expires_at<=?
      `).run(now, now).changes
      const requeued = this.raw.prepare(`
        UPDATE confirmations SET state='pending', decision=NULL, resolved_at=NULL
        WHERE state='sending' AND expires_at>?
      `).run(now).changes
      return { requeued, expired }
    })()
  }

  claimConfirmation(id: string, decision: 'approve' | 'reject'): { requestId: number; eventId: number; result: number } | null {
    return this.raw.transaction(() => {
      const now = new Date().toISOString()
      const row = this.raw.prepare('SELECT * FROM confirmations WHERE id=?').get(id) as any
      if (!row || row.state !== 'pending' || row.expires_at <= now) return null
      const updated = this.raw.prepare(`
        UPDATE confirmations SET state='sending', decision=? WHERE id=? AND state='pending'
      `).run(decision, id)
      if (updated.changes !== 1) return null
      return { requestId: row.request_id, eventId: row.event_id, result: decision === 'approve' ? 2 : 3 }
    })()
  }

  finishConfirmation(id: string, success: boolean, error?: string): void {
    this.raw.prepare(`
      UPDATE confirmations SET state=?, resolved_at=? WHERE id=?
    `).run(success ? 'resolved' : `failed:${error ?? 'unknown'}`, new Date().toISOString(), id)
  }

  createLicense(form: any, creator: string): Record<string, unknown> {
    const now = new Date()
    const nowDate = now.toISOString().slice(0, 10)
    const expire = Array.isArray(form.dateRange) ? String(form.dateRange[1] || nowDate) : nowDate
    const status = expire < nowDate ? '已过期' : Date.parse(`${expire}T23:59:59Z`) - now.getTime() < 7 * 86400000 ? '即将过期' : '有效'
    const id = `LC-${randomUUID().slice(0, 8).toUpperCase()}`
    const hardwarePermissionId = this.nextRequestId()
    const policies = form.policies ?? {}
    const capability = compilePolicyCapability(policies)
    this.raw.prepare(`
      INSERT INTO licenses(id, hardware_permission_id, name, zone, status, policies_json,
        capability_json, creator, create_time, expire_time)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(id, hardwarePermissionId, String(form.name), String(form.zone), status, JSON.stringify(policies), JSON.stringify(capability), creator, nowDate, expire)
    this.audit('license.create', 'license', id, creator, { name: form.name, capability })
    return this.getLicense(id)!
  }

  getLicenses(): Array<Record<string, unknown>> {
    return (this.raw.prepare('SELECT * FROM licenses ORDER BY create_time DESC, id').all() as any[]).map(row => mapLicense(row))
  }

  getLicense(id: string): Record<string, unknown> | null {
    const row = this.raw.prepare('SELECT * FROM licenses WHERE id=?').get(id) as any
    return row ? mapLicense(row) : null
  }

  revokeLicense(id: string, operator: string): boolean {
    const result = this.raw.prepare("UPDATE licenses SET status='已撤销', sync_status='pending_sync' WHERE id=?").run(id)
    if (result.changes > 0) this.audit('license.revoke', 'license', id, operator, {})
    return result.changes > 0
  }

  markLicenseDeployment(id: string, policyVersion: number, status: string): void {
    this.raw.prepare(`UPDATE licenses SET policy_version=?, sync_status=?, last_sync=? WHERE id=?`).run(
      policyVersion, status, status === 'synced' ? new Date().toISOString() : '', id,
    )
  }

  getCards(): { total: number; list: Array<Record<string, unknown>> } {
    const rows = this.raw.prepare(`
      SELECT c.*, l.name AS license_name FROM cards c JOIN licenses l ON l.id=c.license_id ORDER BY c.created_at DESC
    `).all() as any[]
    return { total: rows.length, list: rows.map(row => ({
      id: row.id,
      cardId: formatCardId(row.card_anon_id),
      owner: row.owner,
      licenseId: row.license_id,
      licenseName: row.license_name,
      status: row.status,
      keyVersion: row.key_version,
      lastSync: row.last_sync,
      createdAt: row.created_at,
      syncStatus: row.sync_status,
    })) }
  }

  performCardAction(cardIdText: string, action: string, operator: string): Record<string, unknown> | null {
    const match = /^CARD-([0-9A-Fa-f]{8})$/.exec(cardIdText)
    if (!match) return null
    const numeric = Number.parseInt(match[1]!, 16) >>> 0
    const statuses: Record<string, string> = { revoke: '已撤销', freeze: '已冻结', report_lost: '已挂失', restore: '正常' }
    if (!statuses[action]) return null
    const result = this.raw.prepare(`UPDATE cards SET status=?, sync_status='pending_sync' WHERE card_anon_id=?`).run(statuses[action], numeric)
    if (result.changes === 0) return null
    this.audit(`card.${action}`, 'card', cardIdText, operator, { syncStatus: 'pending_sync' })
    return this.getCards().list.find(card => card.cardId === cardIdText) ?? null
  }

  getInvites(): { total: number; list: Array<Record<string, unknown>> } {
    const rows = this.raw.prepare('SELECT * FROM invites ORDER BY created_at DESC').all() as any[]
    const now = new Date().toISOString()
    const list = rows.map(row => ({
      id: row.id,
      code: row.code,
      role: row.role,
      status: row.status === '未使用' && row.expire_at <= now ? '已过期' : row.status,
      usedBy: row.used_by,
      usedAt: row.used_at,
      expireAt: row.expire_at,
      createdAt: row.created_at,
      revokeReason: row.revoke_reason,
      oneTime: row.one_time === 1,
      maxUses: row.max_uses,
      usedCount: row.used_count,
      remainingUses: Math.max(0, row.max_uses - row.used_count),
    }))
    return { total: list.length, list }
  }

  createInvite(form: any, operator = 'system'): Record<string, unknown> {
    const now = new Date()
    const id = `IV-${randomUUID().slice(0, 8).toUpperCase()}`
    const code = randomBytes(6).toString('base64url').toUpperCase()
    const expireAt = new Date(now.getTime() + Math.max(1, Number(form.expireDays) || 1) * 86400000).toISOString()
    const maxUses = Math.max(1, Number(form.maxUses) || 1)
    this.raw.prepare(`
      INSERT INTO invites(id, code, role, status, expire_at, created_at, one_time, max_uses)
      VALUES (?, ?, ?, '未使用', ?, ?, ?, ?)
    `).run(id, code, String(form.role || '访客'), expireAt, now.toISOString(), maxUses <= 1 ? 1 : 0, maxUses)
    this.recordAudit('invite.create', 'invite', id, operator, {
      role: form.role,
      expireAt,
      maxUses,
    })
    return this.getInvites().list.find(item => item.id === id)!
  }

  revokeInvite(id: string, reason: string, operator: string): boolean {
    const result = this.raw.prepare("UPDATE invites SET status='已撤销', revoke_reason=? WHERE id=? AND status!='已绑定'").run(reason, id)
    if (result.changes > 0) this.audit('invite.revoke', 'invite', id, operator, { reason })
    return result.changes > 0
  }

  redeemInvite(code: string, subject: string, operator = subject): Record<string, unknown> | null {
    return this.raw.transaction(() => {
      const now = new Date().toISOString()
      const row = this.raw.prepare('SELECT * FROM invites WHERE code=?').get(code) as any
      if (!row || row.status === '已撤销' || row.expire_at <= now || row.used_count >= row.max_uses) return null
      const bindingId = `IB-${randomUUID().slice(0, 8).toUpperCase()}`
      try {
        this.raw.prepare(`
          INSERT INTO invite_bindings(id, invite_id, subject, bound_at) VALUES (?, ?, ?, ?)
        `).run(bindingId, row.id, subject, now)
      } catch (error) {
        if (String(error).includes('UNIQUE constraint failed')) return null
        throw error
      }
      const usedCount = Number(row.used_count) + 1
      const exhausted = usedCount >= Number(row.max_uses)
      this.raw.prepare(`
        UPDATE invites SET used_count=?, status=?, used_by=?, used_at=? WHERE id=?
      `).run(usedCount, exhausted ? '已绑定' : '未使用', subject, now, row.id)
      this.recordAudit('invite.redeem', 'invite', row.id, operator, { subject, usedCount, maxUses: row.max_uses })
      return { inviteId: row.id, bindingId, role: row.role, subject, usedAt: now, usedCount, maxUses: row.max_uses, exhausted }
    })()
  }

  recordCommand(requestId: number, commandType: number, payloadHash: string, targetSourceId: number | null): number {
    const result = this.raw.prepare(`
      INSERT INTO device_commands(request_id, command_type, payload_hash, target_source_id, status, created_at)
      VALUES (?, ?, ?, ?, 'pending', ?)
    `).run(requestId, commandType, payloadHash, targetSourceId, new Date().toISOString())
    return Number(result.lastInsertRowid)
  }

  updateCommand(commandId: number, status: string, attempts: number, resultCode?: number, resultValue?: number, error?: string): void {
    this.raw.prepare(`
      UPDATE device_commands SET status=?, attempts=?, result_code=?, result_value=?, error=?, completed_at=?
      WHERE id=?
    `).run(status, attempts, resultCode ?? null, resultValue ?? null, error ?? null, new Date().toISOString(), commandId)
  }

  databaseInfo(): Record<string, unknown> {
    const file = this.raw.name
    const sizeKB = file && file !== ':memory:' && fs.existsSync(file) ? Math.ceil(fs.statSync(file).size / 1024) : 0
    const eventCount = Number((this.raw.prepare('SELECT COUNT(*) AS value FROM events').get() as { value: number }).value)
    const licenseCount = Number((this.raw.prepare('SELECT COUNT(*) AS value FROM licenses').get() as { value: number }).value)
    return { sizeKB, eventCount, licenseCount, lastBackup: this.getSetting<string>('lastBackup') }
  }

  async createBackup(operator: string): Promise<Record<string, unknown>> {
    const databaseFile = this.raw.name
    if (!databaseFile || databaseFile === ':memory:') throw new Error('内存数据库不能创建持久备份')
    const backupDir = path.join(path.dirname(databaseFile), 'backups')
    fs.mkdirSync(backupDir, { recursive: true })
    const now = new Date()
    const stamp = now.toISOString().replace(/[:.]/g, '-').replace('T', '_').replace('Z', '')
    const destination = path.join(backupDir, `starfollow_${stamp}.db`)
    await this.raw.backup(destination)
    const backups = fs.readdirSync(backupDir)
      .filter(name => /^starfollow_.*\.db$/.test(name))
      .sort()
      .reverse()
    for (const expired of backups.slice(7)) {
      const target = path.resolve(backupDir, expired)
      if (path.dirname(target) === path.resolve(backupDir)) fs.unlinkSync(target)
    }
    this.setSetting('lastBackup', now.toISOString())
    this.recordAudit('system.backup', 'database', path.basename(destination), operator, { destination })
    return {
      file: destination,
      createdAt: now.toISOString(),
      sizeKB: Math.ceil(fs.statSync(destination).size / 1024),
    }
  }

  listAuditLogs(query: Record<string, unknown>): { total: number; list: Array<Record<string, unknown>> } {
    const page = Math.max(1, Number(query.page) || 1)
    const pageSize = Math.min(200, Math.max(1, Number(query.pageSize) || 50))
    const total = Number((this.raw.prepare('SELECT COUNT(*) AS value FROM audit_logs').get() as { value: number }).value)
    const rows = this.raw.prepare(`
      SELECT id, action, object_type, object_id, operator, detail_json, created_at
      FROM audit_logs ORDER BY created_at DESC LIMIT ? OFFSET ?
    `).all(pageSize, (page - 1) * pageSize) as Array<Record<string, unknown>>
    return {
      total,
      list: rows.map(row => ({
        id: row.id,
        action: row.action,
        objectType: row.object_type,
        objectId: row.object_id,
        operator: row.operator,
        detail: JSON.parse(String(row.detail_json)),
        createdAt: row.created_at,
      })),
    }
  }

  recordAudit(action: string, objectType: string, objectId: string, operator: string, detail: unknown): void {
    this.raw.prepare(`
      INSERT INTO audit_logs(id, action, object_type, object_id, operator, detail_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(randomUUID(), action, objectType, objectId, operator, JSON.stringify(detail), new Date().toISOString())
  }

  private audit(action: string, objectType: string, objectId: string, operator: string, detail: unknown): void {
    this.recordAudit(action, objectType, objectId, operator, detail)
  }
}

function formatUptime(milliseconds: number): string {
  const seconds = Math.floor(milliseconds / 1000)
  if (seconds < 60) return `${seconds}秒`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}分钟`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}小时`
  return `${Math.floor(hours / 24)}天`
}

function compilePolicyCapability(policies: any): Record<string, string> {
  return {
    recordEvent: policies.recordEvent === false ? 'unsupported' : 'supported',
    allowExecute: 'supported',
    forceConfirm: 'supported',
    unauthorizedAction: ['none', 'log', 'alarm'].includes(policies.unauthorizedAction) ? 'partial' : 'unsupported',
    scope: 'unsupported',
    timeLimit: 'unsupported',
    usageLimit: 'unsupported',
    offlineAllowed: 'supported',
    huaweiFallback: 'backend_only',
    direction: 'unsupported',
  }
}

function mapLicense(row: any): Record<string, unknown> {
  return {
    id: row.id,
    name: row.name,
    zone: row.zone,
    status: row.status,
    cardCount: row.card_count,
    policies: JSON.parse(row.policies_json),
    keyVersion: row.key_version,
    lastSync: row.last_sync,
    creator: row.creator,
    createTime: row.create_time,
    expireTime: row.expire_time,
    hardwarePermissionId: row.hardware_permission_id,
    policyVersion: row.policy_version,
    syncStatus: row.sync_status,
    capability: JSON.parse(row.capability_json),
  }
}
