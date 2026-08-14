# SLE-ID mobile domain contracts

This document freezes mobile-side semantics only. It does not define REST,
WebSocket, Detector B, write-ticket, or SLE Protocol V2 messages.

## Canonical identifiers

`DomainIdentifiers.ets` defines string aliases for `organizationId`,
`detectorId`, `cardAnonId`, `permissionId`, `eventId`, `requestId`, and
`policyVersion`. They remain ordinary strings at runtime. No identifier may
contain a credential, token, authentication secret, or write material.

## Existing model mapping

- `DigitalCard` remains the wallet presentation aggregate. It points to one
  permission and may present a physical credential state, but it is not an
  authoritative receipt.
- `Authorization` remains the individual permission model. Its canonical
  identity is `permissionId`; `organizationId` identifies its issuer.
- `Credential` remains translated physical Card C material. Its write state
  is independent from `Authorization.status`.
- `ConfirmationRequest` owns secondary-confirmation identity and state.
- `Invitation` remains the mock invite preview/redemption contract.
- `PhysicalCard` keeps discovery, connection, capacity, and device condition.
- `PhysicalCardOperation` carries physical operation results plus receipts.

## Permission lifecycle

The frozen `AuthorizationStatus` states are `DRAFT`, `INVITED`, `BOUND`,
`ACTIVE`, `EXPIRED`, `REVOKED`, and `USAGE_EXHAUSTED`.

Migration from the old enum is semantic rather than positional:

- old `PENDING` maps to `DRAFT` before issue or `INVITED` after issue;
- old `ACTIVE` remains `ACTIVE` for existing active permissions;
- new mock redemption produces `BOUND` after durable local invite
  consumption;
- old authorization `FROZEN` and `LOST` are card/credential conditions, not
  permission ownership states;
- old `CANCELLED` maps to `REVOKED` when cancellation invalidates permission.

Permission state is never calculated from credential write state. In
particular, `BOUND` plus `WRITE_FAILED` is valid.

## Physical credential model

`CredentialBindingStatus` is the physical write lifecycle:

`NOT_WRITTEN -> WRITING -> VERIFYING -> ACTIVE`

Failures transition to `WRITE_FAILED`. The `WRITTEN` symbol remains only as a
source/persisted-mock compatibility alias for `ACTIVE`.

`CredentialCondition` is an independent material/security dimension:
`ACTIVE`, `FROZEN`, `LOST`, `EXPIRED`, `REVOKED`, `UPDATE_REQUIRED`, or
`REMOVED`.

NearLink discovery and connection remain in `PhysicalCardDiscoveryState` and
`PhysicalCardConnectionState`; they are not credential write states.
Invitation redemption leaves the credential `NOT_WRITTEN`. Only successful
post-write verification can produce physical `ACTIVE`.

## Confirmation policy

`ConfirmationPolicy.finalConfirmRequired` is represented by the sole domain
function `finalConfirmRequired(adminConfirmRequired, userConfirmEnabled)`:

`adminConfirmRequired || userConfirmEnabled`

`adminConfirmRequired` is read-only input from policy. The canonical
`applyUserConfirmationPreference` rule rejects an attempt to turn off the
effective administrator requirement while allowing users to add protection.
UI and stores call these functions rather than recomputing the rule.

## Confirmation state machine

States are `NOT_REQUIRED`, `PENDING`, `APPROVED`, `REJECTED`, `TIMEOUT`, and
`OFFLINE`. `requestId` is the idempotency identity. `NOT_REQUIRED` and every
state other than `PENDING` are terminal.

`transitionConfirmationRequest` enforces:

- an expired request cannot become `APPROVED`; it becomes `TIMEOUT`;
- repeating the same terminal result is idempotent;
- a different terminal result cannot overwrite an existing terminal result;
- dismissal has no domain transition.

The existing verification dialog now dismisses only after
`ConfirmationStore` records a local mock acknowledgement receipt. That
receipt is explicitly local and does not claim backend confirmation.

## Operation and receipt semantics

The intentionally small operation lifecycle is `IDLE`, `PENDING`,
`ACKNOWLEDGED`, `VERIFIED`, or `FAILED`.

| Current/future operation | Required authority | Success state |
| --- | --- | --- |
| Local card preference | Local persistence | `ACKNOWLEDGED` with local receipt |
| Mock invitation redemption | Local persistence | `ACKNOWLEDGED` with local receipt |
| Local mock confirmation | Local mock store | `ACKNOWLEDGED` with local receipt |
| Future backend security action | Backend | `ACKNOWLEDGED` with backend receipt |
| Physical credential write | Physical Card C readback | `VERIFIED` with physical receipt |

`isAuthoritativeSuccess` requires a receipt identifier and requires
`VERIFIED` whenever `verificationRequired` is true. UI state is never an
operation receipt.

## Synchronization contract

`SyncState` contains `serverRevision`, `lastSyncAt`, and serializable
`pendingOperations`. Each pending operation has an ID, operation type,
authority, timestamps, attempt count, and an opaque non-secret payload
reference. The structure can be persisted after restart without storing
tokens, keys, credentials, or authentication material.

No backend synchronization is implemented in Phase 0C.

## Store boundaries

- `CardStore` continues to own cards, permissions, physical-card presentation,
  and credential presentation. Its local preference writes expose an
  operation receipt.
- `ConfirmationStore` is the only new store. It has an active UI consumer and
  owns local mock confirmation requests, terminal transitions, and receipts.
- No empty `SessionStore` or `SleStore` was created. Their future ownership is
  unchanged but no Phase 0C consumer requires them.
