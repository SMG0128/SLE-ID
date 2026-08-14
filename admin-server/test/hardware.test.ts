import assert from 'node:assert/strict'
import { EventEmitter } from 'node:events'
import { test } from 'node:test'
import { StarFollowDatabase } from '../src/db.js'
import { HardwareService } from '../src/services/hardware.js'
import { AckStatus, FrameFlag, MessageType, type ProtocolFrame, SourceRole } from '../src/ws63/protocol.js'

class MockGateway extends EventEmitter {
  acks: Array<{ messageId: number; status: AckStatus; eventCountAtAck: number }> = []
  constructor(private readonly db: StarFollowDatabase) { super() }
  snapshot() { return { connected: true, detectorBReady: true, gatewaySourceId: 0xb2000001 } }
  send() { return 1 }
  sendAck(frame: ProtocolFrame, status: AckStatus) {
    this.acks.push({ messageId: frame.messageId, status, eventCountAtAck: this.db.listEvents({ page: 1, pageSize: 20 }).total })
  }
  noteDetectorHeartbeat() {}
  async close() {}
}

function makeEventFrame(): ProtocolFrame {
  const payload = Buffer.alloc(40)
  payload.writeUInt32LE(7, 0)
  payload.writeUInt32LE(0xa1000001, 4)
  payload.writeUInt32LE(0x10, 8)
  payload.writeUInt32LE(0xc0000001, 12)
  payload.writeUInt32LE(9, 16)
  payload.writeUInt32LE(1000, 20)
  payload[24] = 1
  payload[25] = 1
  payload[26] = 2
  payload[27] = 0
  payload[28] = 2
  payload[29] = 0
  payload.writeUInt16LE(80, 30)
  payload[32] = 90
  payload[33] = 3
  payload.writeUInt32LE(1010, 34)
  return {
    version: 2,
    type: MessageType.EventReport,
    flags: FrameFlag.AckRequired,
    sourceRole: SourceRole.DetectorB,
    sourceId: 0xb2000001,
    bootId: 0x20,
    messageId: 11,
    payload,
  }
}

async function flush(): Promise<void> {
  await new Promise(resolve => setTimeout(resolve, 20))
}

test('hardware service persists before ACK and returns duplicate ACK on retry', async () => {
  const db = new StarFollowDatabase(':memory:')
  const gateway = new MockGateway(db)
  new HardwareService(gateway as any, db)
  try {
    const frame = makeEventFrame()
    gateway.emit('frame', frame)
    await flush()
    gateway.emit('frame', frame)
    await flush()
    assert.equal(db.listEvents({ page: 1, pageSize: 20 }).total, 1)
    assert.deepEqual(gateway.acks.map(item => item.status), [AckStatus.Accepted, AckStatus.Duplicate])
    assert.deepEqual(gateway.acks.map(item => item.eventCountAtAck), [1, 1])
  } finally {
    db.close()
  }
})
