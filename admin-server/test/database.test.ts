import assert from 'node:assert/strict'
import { test } from 'node:test'
import { StarFollowDatabase } from '../src/db.js'
import { alarmFor, eventResult, eventStatus, formatEventKey, type HardwareEvent } from '../src/domain.js'

test('hardware event ingestion is durable and frame-idempotent', () => {
  const db = new StarFollowDatabase(':memory:')
  try {
    const event: HardwareEvent = {
      eventKey: formatEventKey(0xa1000001, 0x10, 7),
      eventId: 7,
      sourceId: 0xa1000001,
      bootId: 0x10,
      cardAnonId: 0xc0000001,
      permissionId: 9,
      timestampMs: 1000,
      direction: 1,
      auth: 2,
      action: 4,
      confirm: 0,
      execution: 0,
      reason: 1,
      distanceCm: 90,
      confidence: 88,
      state: 3,
      decisionTimestampMs: 1010,
      result: eventResult(2, 0, 0, 1),
      status: eventStatus(4, 0, 0, 1),
      receivedAt: new Date().toISOString(),
    }
    const identity = { sourceId: 0xb2000001, bootId: 0x20, messageId: 11, type: 0x63, receivedAt: event.receivedAt }
    const first = db.ingestEventFrame(identity, event, alarmFor(event.reason, event.execution))
    const duplicate = db.ingestEventFrame(identity, event, alarmFor(event.reason, event.execution))
    assert.equal(first.duplicateFrame, false)
    assert.equal(duplicate.duplicateFrame, true)
    assert.equal(db.listEvents({ page: 1, pageSize: 20 }).total, 1)
    const alarms = db.listAlarms({ page: 1, pageSize: 20 }) as any
    assert.equal(alarms.total, 1)
    assert.equal(alarms.list[0].type, 'unauthorized')
  } finally {
    db.close()
  }
})

test('licenses retain unsupported policy capability status', () => {
  const db = new StarFollowDatabase(':memory:')
  try {
    const license = db.createLicense({
      name: '测试许可',
      zone: '正门大厅',
      dateRange: ['2026-08-01', '2026-12-31'],
      policies: {
        recordEvent: false,
        allowExecute: true,
        forceConfirm: true,
        unauthorizedAction: 'alarm',
        scope: ['正门检测端'],
        timeLimit: { enabled: false },
        usageLimit: { type: 'unlimited', count: 0 },
        offlineAllowed: true,
        huaweiFallback: false,
        direction: 'both',
      },
    }, 'tester') as any
    assert.equal(license.capability.allowExecute, 'supported')
    assert.equal(license.capability.recordEvent, 'unsupported')
    assert.equal(license.capability.scope, 'unsupported')
    assert.equal(license.syncStatus, 'saved')
  } finally {
    db.close()
  }
})

test('policy versions are global and command request IDs may repeat after a device reboot', () => {
  const db = new StarFollowDatabase(':memory:')
  try {
    assert.equal(db.nextPolicyVersion(), 1)
    assert.equal(db.nextPolicyVersion(), 2)

    const first = db.recordCommand(1, 0x65, 'payload-a', 0xb2000001)
    const afterReboot = db.recordCommand(1, 0x65, 'payload-b', 0xb2000001)
    assert.notEqual(first, afterReboot)
    db.updateCommand(first, 'success', 1, 0, 7)
    db.updateCommand(afterReboot, 'failed', 2, undefined, undefined, 'timeout')

    const rows = db.raw.prepare(`
      SELECT id, status, attempts FROM device_commands ORDER BY id
    `).all() as Array<{ id: number; status: string; attempts: number }>
    assert.deepEqual(rows, [
      { id: first, status: 'success', attempts: 1 },
      { id: afterReboot, status: 'failed', attempts: 2 },
    ])
  } finally {
    db.close()
  }
})

test('startup recovery requeues live sending confirmations and expires stale ones', () => {
  const db = new StarFollowDatabase(':memory:')
  try {
    const future = new Date(Date.now() + 60_000).toISOString()
    const past = new Date(Date.now() - 60_000).toISOString()
    const insert = db.raw.prepare(`
      INSERT INTO confirmations(id, gateway_source_id, gateway_boot_id, request_id, event_id,
        card_anon_id, permission_id, device_timestamp_ms, action, direction, state, decision,
        expires_at, received_at)
      VALUES (?, 1, 2, ?, ?, 3, 4, 5, 2, 1, 'sending', 'approve', ?, ?)
    `)
    insert.run('CF-LIVE', 10, 20, future, new Date().toISOString())
    insert.run('CF-STALE', 11, 21, past, past)
    assert.deepEqual(db.recoverInterruptedConfirmations(), { requeued: 1, expired: 1 })
    const live = db.raw.prepare('SELECT state, decision FROM confirmations WHERE id=?').get('CF-LIVE') as any
    const stale = db.raw.prepare('SELECT state, resolved_at FROM confirmations WHERE id=?').get('CF-STALE') as any
    assert.deepEqual(live, { state: 'pending', decision: null })
    assert.equal(stale.state, 'expired')
    assert.ok(stale.resolved_at)
  } finally {
    db.close()
  }
})

test('invite redemption consumes uses atomically and prevents duplicate binding', () => {
  const db = new StarFollowDatabase(':memory:')
  try {
    const invite = db.createInvite({ role: '操作员', expireDays: 7, maxUses: 2 }, 'admin') as any
    const first = db.redeemInvite(invite.code, 'user-a', 'admin') as any
    assert.equal(first.usedCount, 1)
    assert.equal(first.exhausted, false)
    assert.equal(db.redeemInvite(invite.code, 'user-a', 'admin'), null)
    const second = db.redeemInvite(invite.code, 'user-b', 'admin') as any
    assert.equal(second.usedCount, 2)
    assert.equal(second.exhausted, true)
    assert.equal(db.redeemInvite(invite.code, 'user-c', 'admin'), null)
    const current = db.getInvites().list[0] as any
    assert.equal(current.status, '已绑定')
    assert.equal(current.usedCount, 2)
    assert.equal(current.remainingUses, 0)
    assert.equal(current.oneTime, false)
  } finally {
    db.close()
  }
})
