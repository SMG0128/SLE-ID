export const SLEKEY_DEVICE_NAME: string = 'SLEKEY-A'
export const SLEKEY_SERVICE_UUID: string = '7A7B0001-6D8F-4A4E-9A5D-53B7A1000001'
export const SLEKEY_CONTROL_UUID: string = '7A7B0002-6D8F-4A4E-9A5D-53B7A1000001'
export const SLEKEY_STATUS_UUID: string = '7A7B0003-6D8F-4A4E-9A5D-53B7A1000001'
export const SLEKEY_DEVICE_INFO_UUID: string = '7A7B0004-6D8F-4A4E-9A5D-53B7A1000001'

const MAGIC_0: number = 0x53
const MAGIC_1: number = 0x4B
const PROTOCOL_VERSION: number = 0x01
const HEADER_LENGTH: number = 8
const CRC_LENGTH: number = 2
export const MAX_PAYLOAD_LENGTH: number = 256

export enum NearLinkMessageType {
  HELLO = 0x01,
  PING = 0x02,
  GET_DEVICE_INFO = 0x03,
  HELLO_ACK = 0x81,
  PONG = 0x82,
  DEVICE_INFO = 0x83,
  PROTOCOL_ERROR = 0xE0,
  CRC_ERROR = 0xE1,
  UNSUPPORTED_COMMAND = 0xE2,
  INTERNAL_ERROR = 0xEF
}

export interface NearLinkFrame {
  type: NearLinkMessageType
  sequence: number
  payload: Uint8Array
}

export class NearLinkProtocol {
  static encode(type: NearLinkMessageType, sequence: number, payload?: Uint8Array): ArrayBuffer {
    const body: Uint8Array = payload ? payload : new Uint8Array(0)
    if (body.byteLength > MAX_PAYLOAD_LENGTH) {
      throw new Error(`payload too large: ${body.byteLength}`)
    }

    const bytes: Uint8Array = new Uint8Array(HEADER_LENGTH + body.byteLength + CRC_LENGTH)
    bytes[0] = MAGIC_0
    bytes[1] = MAGIC_1
    bytes[2] = PROTOCOL_VERSION
    bytes[3] = type
    NearLinkProtocol.writeLe16(bytes, 4, sequence)
    NearLinkProtocol.writeLe16(bytes, 6, body.byteLength)
    bytes.set(body, HEADER_LENGTH)
    NearLinkProtocol.writeLe16(bytes, bytes.byteLength - CRC_LENGTH,
      NearLinkProtocol.crc16Ccitt(bytes, bytes.byteLength - CRC_LENGTH))
    return bytes.buffer
  }

  static decode(buffer: ArrayBuffer): NearLinkFrame {
    const bytes: Uint8Array = new Uint8Array(buffer)
    if (bytes.byteLength < HEADER_LENGTH + CRC_LENGTH) {
      throw new Error('protocol frame is shorter than 10 bytes')
    }
    if (bytes[0] !== MAGIC_0 || bytes[1] !== MAGIC_1) {
      throw new Error('protocol magic mismatch')
    }
    if (bytes[2] !== PROTOCOL_VERSION) {
      throw new Error(`unsupported protocol version: ${bytes[2]}`)
    }

    const payloadLength: number = NearLinkProtocol.readLe16(bytes, 6)
    if (payloadLength > MAX_PAYLOAD_LENGTH) {
      throw new Error(`payload length exceeds ${MAX_PAYLOAD_LENGTH}`)
    }
    if (bytes.byteLength !== HEADER_LENGTH + payloadLength + CRC_LENGTH) {
      throw new Error('payloadLength does not match frame length')
    }

    const expectedCrc: number = NearLinkProtocol.readLe16(bytes, bytes.byteLength - CRC_LENGTH)
    const actualCrc: number = NearLinkProtocol.crc16Ccitt(bytes, bytes.byteLength - CRC_LENGTH)
    if (expectedCrc !== actualCrc) {
      throw new Error(`CRC mismatch: expected 0x${expectedCrc.toString(16)}, actual 0x${actualCrc.toString(16)}`)
    }

    const payload: Uint8Array = new Uint8Array(payloadLength)
    payload.set(bytes.subarray(HEADER_LENGTH, HEADER_LENGTH + payloadLength))
    return {
      type: bytes[3] as NearLinkMessageType,
      sequence: NearLinkProtocol.readLe16(bytes, 4),
      payload: payload
    }
  }

  static hex(bytes: Uint8Array): string {
    let result: string = ''
    for (let index: number = 0; index < bytes.byteLength; index++) {
      if (index > 0) {
        result += ' '
      }
      result += bytes[index].toString(16).padStart(2, '0').toUpperCase()
    }
    return result
  }

  private static readLe16(bytes: Uint8Array, offset: number): number {
    return bytes[offset] | (bytes[offset + 1] << 8)
  }

  private static writeLe16(bytes: Uint8Array, offset: number, value: number): void {
    bytes[offset] = value & 0xFF
    bytes[offset + 1] = (value >> 8) & 0xFF
  }

  private static crc16Ccitt(bytes: Uint8Array, length: number): number {
    let crc: number = 0xFFFF
    for (let index: number = 0; index < length; index++) {
      crc ^= bytes[index] << 8
      for (let bit: number = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF
      }
    }
    return crc
  }
}
