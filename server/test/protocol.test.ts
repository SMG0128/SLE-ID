import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  crc16Ccitt,
  decodeFrame,
  encodeFrame,
  FrameFlag,
  MessageType,
  SourceRole,
  StreamParser,
} from '../src/ws63/protocol.js'

test('CRC16-CCITT matches the standard check vector', () => {
  assert.equal(crc16Ccitt(Buffer.from('123456789', 'ascii')), 0x29b1)
})

test('Protocol V2 frame round-trips all header fields', () => {
  const encoded = encodeFrame({
    type: MessageType.EventReport,
    flags: FrameFlag.AckRequired,
    sourceRole: SourceRole.DetectorB,
    sourceId: 0xb2000001,
    bootId: 0x01020304,
    messageId: 99,
    payload: Buffer.from([1, 2, 3, 4]),
  })
  const decoded = decodeFrame(encoded)
  assert.equal(decoded.type, MessageType.EventReport)
  assert.equal(decoded.flags, FrameFlag.AckRequired)
  assert.equal(decoded.sourceRole, SourceRole.DetectorB)
  assert.equal(decoded.sourceId, 0xb2000001)
  assert.equal(decoded.bootId, 0x01020304)
  assert.equal(decoded.messageId, 99)
  assert.deepEqual([...decoded.payload], [1, 2, 3, 4])
})

test('stream parser ignores text logs and handles split frames', () => {
  const parser = new StreamParser()
  const frame = encodeFrame({
    type: MessageType.Heartbeat,
    flags: 0,
    sourceRole: SourceRole.DetectorB,
    sourceId: 3,
    bootId: 4,
    messageId: 5,
    payload: Buffer.alloc(20, 0x11),
  })
  assert.equal(parser.push(Buffer.concat([Buffer.from('LED toggle.\r\n'), frame.subarray(0, 9)])).length, 0)
  const frames = parser.push(frame.subarray(9))
  assert.equal(frames.length, 1)
  assert.equal(frames[0]!.messageId, 5)
  assert.ok(parser.discardedBytes >= 'LED toggle.\r\n'.length)
})

test('stream parser rejects bad CRC and resynchronizes to the next frame', () => {
  const parser = new StreamParser()
  const bad = encodeFrame({
    type: MessageType.Heartbeat,
    flags: 0,
    sourceRole: SourceRole.DetectorB,
    sourceId: 1,
    bootId: 2,
    messageId: 3,
    payload: Buffer.alloc(0),
  })
  bad[bad.length - 1] = (bad[bad.length - 1] ?? 0) ^ 0xff
  const good = encodeFrame({
    type: MessageType.Heartbeat,
    flags: 0,
    sourceRole: SourceRole.DetectorB,
    sourceId: 1,
    bootId: 2,
    messageId: 4,
    payload: Buffer.alloc(0),
  })
  const frames = parser.push(Buffer.concat([bad, good]))
  assert.equal(frames.length, 1)
  assert.equal(frames[0]!.messageId, 4)
  assert.equal(parser.crcErrors, 1)
})
