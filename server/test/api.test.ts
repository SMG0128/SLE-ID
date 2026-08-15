import assert from 'node:assert/strict'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { test } from 'node:test'
import type { AddressInfo } from 'node:net'
import { createRuntime } from '../src/runtime.js'
import { WebSocket } from 'ws'

function connectWebSocket(url: string, bearer?: string): Promise<{ opened: boolean; status?: number }> {
  return new Promise(resolve => {
    const socket = new WebSocket(url, bearer ? { headers: { authorization: `Bearer ${bearer}` } } : undefined)
    socket.once('open', () => {
      socket.terminate()
      resolve({ opened: true })
    })
    socket.once('unexpected-response', (_request, response) => {
      socket.terminate()
      resolve({ opened: false, status: response.statusCode })
    })
    socket.once('error', () => resolve({ opened: false }))
  })
}

test('REST API starts without hardware and exposes capability-safe behavior', async () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'starfollow-test-'))
  const runtime = createRuntime({
    host: '127.0.0.1',
    port: 0,
    dataDir: directory,
    databasePath: path.join(directory, 'test.db'),
    frontendDist: path.join(directory, 'missing-dist'),
    hostSourceId: 0x48000001,
    hostBootId: 0x12345678,
  })
  try {
    await runtime.start()
    assert.equal(runtime.db.getSetting<number>('hostSourceId'), 0x48000001)
    const address = runtime.server.address() as AddressInfo
    const base = `http://127.0.0.1:${address.port}`
    const health = await fetch(`${base}/api/health`).then(response => response.json()) as any
    assert.equal(health.code, 0)
    assert.equal(health.data.serial.connected, false)

    const create = await fetch(`${base}/api/licenses`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        name: 'API许可',
        zone: '正门大厅',
        dateRange: ['2026-08-01', '2026-12-31'],
        policies: { allowExecute: true, forceConfirm: false, offlineAllowed: true, unauthorizedAction: 'log' },
      }),
    }).then(response => response.json()) as any
    assert.equal(create.code, 0)
    assert.equal(create.data.syncStatus, 'saved')

    const restartResponse = await fetch(`${base}/api/devices/DEV-1/restart`, { method: 'POST' })
    const restart = await restartResponse.json() as any
    assert.equal(restartResponse.status, 501)
    assert.equal(restart.code, 3002)
  } finally {
    await runtime.stop()
    rmSync(directory, { recursive: true, force: true })
  }
})

test('configured token protects REST and ignores spoofed operator identity', async () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'starfollow-auth-test-'))
  const runtime = createRuntime({
    host: '127.0.0.1', port: 0, dataDir: directory,
    databasePath: path.join(directory, 'test.db'), frontendDist: path.join(directory, 'missing-dist'),
    hostSourceId: 0x48000002, hostBootId: 0x12345679,
    apiToken: 'test-secret-token', adminOperator: 'authenticated-admin',
  })
  try {
    await runtime.start()
    const address = runtime.server.address() as AddressInfo
    const base = `http://127.0.0.1:${address.port}`
    const denied = await fetch(`${base}/api/health`)
    assert.equal(denied.status, 401)
    const deniedWs = await connectWebSocket(`ws://127.0.0.1:${address.port}/ws/events`)
    assert.deepEqual(deniedWs, { opened: false, status: 401 })
    const allowedWs = await connectWebSocket(`ws://127.0.0.1:${address.port}/ws/events?access_token=test-secret-token`)
    assert.equal(allowedWs.opened, true)
    const allowed = await fetch(`${base}/api/invites`, {
      method: 'POST',
      headers: { authorization: 'Bearer test-secret-token', 'content-type': 'application/json', 'x-operator': 'spoofed' },
      body: JSON.stringify({ role: '操作员', maxUses: 1 }),
    })
    assert.equal(allowed.status, 200)
    const audit = runtime.db.listAuditLogs({ page: 1, pageSize: 10 }) as any
    assert.equal(audit.list[0].operator, 'authenticated-admin')
  } finally {
    await runtime.stop()
    rmSync(directory, { recursive: true, force: true })
  }
})

test('non-loopback binding requires an access token', () => {
  assert.throws(() => createRuntime({
    host: '0.0.0.0', port: 0, dataDir: '.', databasePath: ':memory:', frontendDist: '.',
    hostSourceId: 1, hostBootId: 2,
  }), /STARFOLLOW_API_TOKEN/)
})

test('mobile bootstrap pairs a device and protects wallet routes', async () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'starfollow-mobile-test-'))
  const runtime = createRuntime({
    host: '127.0.0.1', port: 0, dataDir: directory,
    databasePath: path.join(directory, 'test.db'), frontendDist: path.join(directory, 'missing-dist'),
    hostSourceId: 0x48000003, hostBootId: 0x1234567a,
    mobilePairingCode: 'PAIR-TEST-2026',
  })
  try {
    await runtime.start()
    const address = runtime.server.address() as AddressInfo
    const base = `http://127.0.0.1:${address.port}`
    const deniedPair = await fetch(`${base}/api/mobile/pair`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ pairingCode: 'wrong', deviceId: 'tablet-1', deviceName: 'test' }),
    })
    assert.equal(deniedPair.status, 401)

    const pairResponse = await fetch(`${base}/api/mobile/pair`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ pairingCode: 'PAIR-TEST-2026', deviceId: 'tablet-1', deviceName: 'test' }),
    })
    assert.equal(pairResponse.status, 200)
    const pair = await pairResponse.json() as any
    assert.equal(pair.session.subjectId, 'mobile:tablet-1')
    assert.ok(pair.session.accessToken.length >= 32)
    assert.equal((runtime.db.listAuditLogs({ page: 1, pageSize: 10 }) as any).list[0].action, 'mobile.pair')

    const deniedMobileWs = await connectWebSocket(`ws://127.0.0.1:${address.port}/ws/mobile`)
    assert.deepEqual(deniedMobileWs, { opened: false, status: 401 })
    const allowedMobileWs = await connectWebSocket(
      `ws://127.0.0.1:${address.port}/ws/mobile`,
      pair.session.accessToken,
    )
    assert.equal(allowedMobileWs.opened, true)

    const deniedWallet = await fetch(`${base}/api/mobile/cards`)
    assert.equal(deniedWallet.status, 401)
    const headers = { authorization: `Bearer ${pair.session.accessToken}` }
    const wallet = await fetch(`${base}/api/mobile/cards`, { headers }).then(response => response.json()) as any
    assert.deepEqual(wallet.cards, [])
    assert.deepEqual(wallet.authorizations, [])
    const pending = await fetch(`${base}/api/mobile/confirmations/pending`, { headers }).then(response => response.json()) as any
    assert.deepEqual(pending.confirmations, [])
  } finally {
    await runtime.stop()
    rmSync(directory, { recursive: true, force: true })
  }
})
