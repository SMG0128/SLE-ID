# SLEKEY-A NearLink protocol

This document is the shared wire contract for the HarmonyOS App and BearPi_A firmware. Multi-byte integers are little-endian.

## SSAP identity

| Item | Value |
| --- | --- |
| Device name | `SLEKEY-A` |
| Service | `7A7B0001-6D8F-4A4E-9A5D-53B7A1000001` |
| Control (App write) | `7A7B0002-6D8F-4A4E-9A5D-53B7A1000001` |
| Status (BearPi_A notify, App read/subscribe) | `7A7B0003-6D8F-4A4E-9A5D-53B7A1000001` |
| Device info (App read) | `7A7B0004-6D8F-4A4E-9A5D-53B7A1000001` |

The primary advertising packet contains the complete local name and the complete 128-bit Service UUID. The local API 22 `scan.ScanFilters` type has no Service UUID member and rejects empty filters with `BusinessError 401`, so the App uses the exact device name as the OS scan filter. It checks the raw advertising data for the Service UUID when API 22 exposes that record, and always requires the exact SSAP Service UUID and Property contract after the link is established.

## Frame

| Offset | Size | Meaning |
| --- | ---: | --- |
| 0 | 1 | Magic 0: `0x53` |
| 1 | 1 | Magic 1: `0x4B` |
| 2 | 1 | Version: `0x01` |
| 3 | 1 | Message type |
| 4 | 2 | Sequence, little-endian `uint16` |
| 6 | 2 | Payload length, little-endian `uint16` |
| 8 | N | Payload, maximum 256 bytes |
| 8+N | 2 | CRC16-CCITT, little-endian |

CRC parameters: polynomial `0x1021`, initial value `0xFFFF`, no reflection, no final XOR. The CRC covers the header and payload, excluding the final two CRC bytes.

## Message types

| Request | Response | Required sequence rule |
| --- | --- | --- |
| `0x01 HELLO` | `0x81 HELLO_ACK` | Response equals request |
| `0x02 PING` | `0x82 PONG` | Response equals request |
| `0x03 GET_DEVICE_INFO` | `0x83 DEVICE_INFO` | Response equals request |

Errors are `0xE0 PROTOCOL_ERROR`, `0xE1 CRC_ERROR`, `0xE2 UNSUPPORTED_COMMAND`, and `0xEF INTERNAL_ERROR`.

The App enters `CONNECTED` when SSAP links, `HANDSHAKING` after writing HELLO, and `READY` only after a frame passes magic, version, exact length, CRC, expected message type, and expected sequence validation. Receiving arbitrary bytes never marks the connection usable.

## Device info payload

The read-only device-info property returns one full `DEVICE_INFO` frame. Its payload is:

1. `protocolVersion` (`uint8`)
2. `role` (`uint8`, currently `0x01` = SSAP server/advertiser)
3. firmware version length (`uint8`) and UTF-8 bytes
4. test device ID length (`uint8`) and UTF-8 bytes
5. build time length (`uint8`) and UTF-8 bytes

The current device ID is a test-domain identifier and is not a user identity, credential, or production key.
