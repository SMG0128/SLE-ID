# NearLink integration

## App integration

The existing `ScanPage` opened by the “临时连接 / Temporary connection” navigation entry owns only rendering and user actions. `NearLinkConnectionService` owns permission, capability checks, scan lifetime, address deduplication, SSAP client lifetime, service discovery, property notification, handshake timeouts, and protocol callbacks. `NearLinkProtocol` owns frame encoding, decoding, bounds checks, and CRC16-CCITT.

The project uses HarmonyOS SDK `6.1.0(23)` with target API 23 and compatible API 13. API 13 is the minimum because the existing NearLink scan result, manager, scan, and SSAP APIs are declared from `5.0.1(13)`. The declarations verified locally are:

- `manager.isNearLinkSupported()` and `manager.getState()`
- `scan.on('deviceFound')`, `scan.startScan()`, `scan.stopScan()`, `scan.off('deviceFound')`
- `ssap.createClient(address)`
- `Client.on/off`, `connect`, `getServices`, `writeProperty`, `readProperty`, `setPropertyNotification`, `disconnect`, and `close`

`ohos.permission.ACCESS_NEARLINK` is a normal `user_grant` permission in the local SDK. It is declared with an in-use reason/scene and requested when the user starts a scan. The App does not automatically open system settings.

## Lifecycle and recovery

- Scan uses the SDK's 10-second duration plus a local cleanup timer.
- Starting a connection stops scanning and removes the scan listener.
- Leaving the page stops scan, disables notification when possible, unregisters callbacks, clears timers, disconnects, and closes the client.
- Ability destruction repeats idempotent cleanup.
- A disconnected client is released before a later scan/reconnect.
- Scan and protocol errors preserve a concrete message for the page's “最近错误” field.

## Scope

Currently implemented in code:

- in-app scan and device list with name/address/RSSI
- in-app SSAP client connection
- SSAP control-property write and status-property notification
- binary HELLO/HELLO_ACK and PING/PONG validation
- explicit disconnect and reconnect resource cleanup

Not completed and not claimed by this stage:

- production card identity authentication
- credential/authorization writing
- key exchange or production credential material
- invitation-code binding
- replay protection and multi-authorization storage
- Channel Sounding / passive check-in
- real-device end-to-end acceptance (requires supported Huawei hardware and BearPi_A)
# SSAP implementation audit

The temporary connection page uses a real NearLink SSAP client. It does not use the
application's mock card data source. The client creates an `ssap.Client`, connects,
discovers the SLEKEY service and all three properties, explicitly enables status
notifications, writes HELLO/PING to the discovered control property, and validates
the returned frame and sequence.

On API 22, NearLink Kit rejects both an empty filter array and an empty filter
object with `BusinessError 401`, so discovery uses the exact device name
`SLEKEY-A` at the SDK boundary. The App still validates the candidate name/service
UUID and, after connecting, requires the exact service, control, status, and
device-info UUIDs together with their required operations and descriptors.
