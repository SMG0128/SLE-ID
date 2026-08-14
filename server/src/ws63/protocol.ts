export const PROTOCOL_VERSION = 2
export const FRAME_MAGIC_0 = 0x53
export const FRAME_MAGIC_1 = 0x4c
export const MAX_PAYLOAD = 64
export const FRAME_HEADER_SIZE = 20
export const FRAME_OVERHEAD = 22

export enum SourceRole {
  Unknown = 0,
  Card = 1,
  DetectorA = 2,
  DetectorB = 3,
  Host = 4,
}

export enum MessageType {
  PassageEvent = 0x10,
  Decision = 0x20,
  Heartbeat = 0x30,
  PolicySync = 0x60,
  PolicyResult = 0x61,
  EventReport = 0x62,
  AlertReport = 0x63,
  ConfirmRequest = 0x64,
  ConfirmResult = 0x65,
  CommandResult = 0x66,
  Ack = 0x7f,
}

export enum FrameFlag {
  AckRequired = 0x01,
  Response = 0x02,
  Retry = 0x04,
}

export enum AckStatus {
  Accepted = 0,
  Duplicate = 1,
  BadMessage = 2,
  Busy = 3,
}

export interface ProtocolFrame {
  version: number
  type: number
  flags: number
  sourceRole: number
  sourceId: number
  bootId: number
  messageId: number
  payload: Buffer
}

export function crc16Ccitt(data: Uint8Array): number {
  let crc = 0xffff
  for (const value of data) {
    crc ^= value << 8
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff
    }
  }
  return crc
}

export function encodeFrame(frame: Omit<ProtocolFrame, 'version'> & { version?: number }): Buffer {
  if (frame.payload.length > MAX_PAYLOAD) throw new RangeError('Protocol payload exceeds 64 bytes')
  const output = Buffer.alloc(FRAME_OVERHEAD + frame.payload.length)
  output[0] = FRAME_MAGIC_0
  output[1] = FRAME_MAGIC_1
  output[2] = frame.version ?? PROTOCOL_VERSION
  output[3] = frame.type & 0xff
  output[4] = frame.flags & 0xff
  output[5] = frame.sourceRole & 0xff
  output.writeUInt32LE(frame.sourceId >>> 0, 6)
  output.writeUInt32LE(frame.bootId >>> 0, 10)
  output.writeUInt32LE(frame.messageId >>> 0, 14)
  output.writeUInt16LE(frame.payload.length, 18)
  frame.payload.copy(output, 20)
  output.writeUInt16LE(crc16Ccitt(output.subarray(2, 20 + frame.payload.length)), 20 + frame.payload.length)
  return output
}

export function decodeFrame(bytes: Uint8Array): ProtocolFrame {
  const data = Buffer.from(bytes)
  if (data.length < FRAME_OVERHEAD) throw new Error('Protocol frame is too short')
  if (data[0] !== FRAME_MAGIC_0 || data[1] !== FRAME_MAGIC_1) throw new Error('Protocol magic mismatch')
  if (data[2] !== PROTOCOL_VERSION) throw new Error(`Unsupported protocol version ${data[2]}`)
  const payloadLength = data.readUInt16LE(18)
  if (payloadLength > MAX_PAYLOAD || data.length !== FRAME_OVERHEAD + payloadLength) {
    throw new Error('Protocol frame length mismatch')
  }
  const expected = data.readUInt16LE(20 + payloadLength)
  const actual = crc16Ccitt(data.subarray(2, 20 + payloadLength))
  if (expected !== actual) throw new Error('Protocol CRC mismatch')
  const sourceRole = data[5] ?? 0
  if (sourceRole > SourceRole.Host) throw new Error('Protocol source role is invalid')
  return {
    version: data[2] ?? 0,
    type: data[3] ?? 0,
    flags: data[4] ?? 0,
    sourceRole,
    sourceId: data.readUInt32LE(6),
    bootId: data.readUInt32LE(10),
    messageId: data.readUInt32LE(14),
    payload: data.subarray(20, 20 + payloadLength),
  }
}

export class StreamParser {
  private buffer = Buffer.alloc(0)
  crcErrors = 0
  formatErrors = 0
  discardedBytes = 0

  push(chunk: Uint8Array): ProtocolFrame[] {
    if (chunk.length === 0) return []
    this.buffer = Buffer.concat([this.buffer, Buffer.from(chunk)])
    const frames: ProtocolFrame[] = []
    while (this.buffer.length >= 2) {
      const magic = this.findMagic()
      if (magic < 0) {
        const keepMagicPrefix = this.buffer.at(-1) === FRAME_MAGIC_0
        this.discardedBytes += this.buffer.length - (keepMagicPrefix ? 1 : 0)
        this.buffer = keepMagicPrefix ? Buffer.from([FRAME_MAGIC_0]) : Buffer.alloc(0)
        break
      }
      if (magic > 0) {
        this.discardedBytes += magic
        this.buffer = this.buffer.subarray(magic)
      }
      if (this.buffer.length < FRAME_HEADER_SIZE) break
      const version = this.buffer[2]
      const role = this.buffer[5]
      const payloadLength = this.buffer.readUInt16LE(18)
      if (version !== PROTOCOL_VERSION || role === undefined || role > SourceRole.Host || payloadLength > MAX_PAYLOAD) {
        this.formatErrors += 1
        this.discardedBytes += 1
        this.buffer = this.buffer.subarray(1)
        continue
      }
      const total = FRAME_OVERHEAD + payloadLength
      if (this.buffer.length < total) break
      const candidate = this.buffer.subarray(0, total)
      try {
        frames.push(decodeFrame(candidate))
        this.buffer = this.buffer.subarray(total)
      } catch (error) {
        if (error instanceof Error && error.message.includes('CRC')) this.crcErrors += 1
        else this.formatErrors += 1
        this.discardedBytes += 1
        this.buffer = this.buffer.subarray(1)
      }
    }
    return frames
  }

  reset(): void {
    this.buffer = Buffer.alloc(0)
  }

  private findMagic(): number {
    for (let index = 0; index + 1 < this.buffer.length; index += 1) {
      if (this.buffer[index] === FRAME_MAGIC_0 && this.buffer[index + 1] === FRAME_MAGIC_1) return index
    }
    return -1
  }
}

export function readU32(payload: Buffer, offset: number): number {
  if (offset < 0 || offset + 4 > payload.length) throw new RangeError('u32 payload read exceeds bounds')
  return payload.readUInt32LE(offset)
}

export function writeU32(payload: Buffer, offset: number, value: number): void {
  payload.writeUInt32LE(value >>> 0, offset)
}
