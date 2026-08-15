export const CARD_C_DEVICE_NAME: string = 'sle_card'
export const CARD_C_SERVICE_UUID: string = '2C00'
export const CARD_C_INFO_UUID: string = '2C01'
export const CARD_C_COMMAND_UUID: string = '2C02'
export const CARD_C_RESPONSE_UUID: string = '2C03'
export const CARD_C_STATUS_UUID: string = '2C04'
export const CARD_C_MAX_CHUNK_BYTES: number = 48

export enum CardCMessageType {
  CARD_INFO = 0x40,
  CREDENTIAL_BEGIN = 0x41,
  CREDENTIAL_CHUNK = 0x42,
  CREDENTIAL_COMMIT = 0x43,
  CREDENTIAL_RESULT = 0x44,
  CREDENTIAL_LIST = 0x45
}

export interface CardCFrame {
  type: number
  sourceRole: number
  sourceId: number
  bootId: number
  messageId: number
  payload: Uint8Array
}

export class CardCProtocol {
  static encode(type: number, sourceId: number, bootId: number,
    messageId: number, payload: Uint8Array): ArrayBuffer {
    if (payload.byteLength > 64) {
      throw new Error('Card C payload exceeds Protocol V2 maximum')
    }
    const frame: Uint8Array = new Uint8Array(22 + payload.byteLength)
    frame[0] = 0x53
    frame[1] = 0x4C
    frame[2] = 2
    frame[3] = type
    frame[4] = 0x01
    frame[5] = 4 // AB_ROLE_HOST
    this.writeU32(frame, 6, sourceId)
    this.writeU32(frame, 10, bootId)
    this.writeU32(frame, 14, messageId)
    this.writeU16(frame, 18, payload.byteLength)
    frame.set(payload, 20)
    this.writeU16(frame, 20 + payload.byteLength,
      this.crc16(frame.subarray(2, 20 + payload.byteLength)))
    return frame.buffer
  }

  static decode(value: ArrayBuffer): CardCFrame {
    const frame: Uint8Array = new Uint8Array(value)
    if (frame.byteLength < 22 || frame[0] !== 0x53 || frame[1] !== 0x4C ||
      frame[2] !== 2) {
      throw new Error('Card C returned an invalid Protocol V2 frame')
    }
    const payloadLength: number = this.readU16(frame, 18)
    if (payloadLength > 64 || frame.byteLength !== payloadLength + 22) {
      throw new Error('Card C frame length mismatch')
    }
    const expected: number = this.readU16(frame, 20 + payloadLength)
    const actual: number = this.crc16(frame.subarray(2, 20 + payloadLength))
    if (expected !== actual) {
      throw new Error('Card C frame CRC mismatch')
    }
    const payload: Uint8Array = new Uint8Array(payloadLength)
    payload.set(frame.subarray(20, 20 + payloadLength))
    return {
      type: frame[3],
      sourceRole: frame[5],
      sourceId: this.readU32(frame, 6),
      bootId: this.readU32(frame, 10),
      messageId: this.readU32(frame, 14),
      payload: payload
    }
  }

  static crc32(data: Uint8Array): number {
    let crc: number = 0xFFFFFFFF
    for (let index: number = 0; index < data.byteLength; index++) {
      crc = (crc ^ data[index]) >>> 0
      for (let bit: number = 0; bit < 8; bit++) {
        crc = (crc & 1) !== 0 ? ((crc >>> 1) ^ 0xEDB88320) >>> 0 : crc >>> 1
      }
    }
    return (~crc) >>> 0
  }

  static readU16(data: Uint8Array, offset: number): number {
    return data[offset] | (data[offset + 1] << 8)
  }

  static readU32(data: Uint8Array, offset: number): number {
    return (data[offset] | (data[offset + 1] << 8) |
      (data[offset + 2] << 16) | (data[offset + 3] << 24)) >>> 0
  }

  static writeU16(data: Uint8Array, offset: number, value: number): void {
    data[offset] = value & 0xFF
    data[offset + 1] = (value >>> 8) & 0xFF
  }

  static writeU32(data: Uint8Array, offset: number, value: number): void {
    data[offset] = value & 0xFF
    data[offset + 1] = (value >>> 8) & 0xFF
    data[offset + 2] = (value >>> 16) & 0xFF
    data[offset + 3] = (value >>> 24) & 0xFF
  }

  private static crc16(data: Uint8Array): number {
    let crc: number = 0xFFFF
    for (let index: number = 0; index < data.byteLength; index++) {
      crc ^= data[index] << 8
      for (let bit: number = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF :
          (crc << 1) & 0xFFFF
      }
    }
    return crc
  }
}
