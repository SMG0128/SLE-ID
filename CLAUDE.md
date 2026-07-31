# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SleKey (SLE-ID) is a HarmonyOS ArkUI application for near-field identification based on SLE (Sparkling Link Enhanced). It manages digital identity/transit/access cards and credentials that can be written to physical WS63 cards. The app is bilingual (Chinese/English) and currently runs entirely on mock data.

- **Bundle**: `com.slekey.app`
- **Platform**: HarmonyOS 6 (compileSdkVersion 6.1.0, compatible to 5.0.0)
- **Devices**: phone, tablet (portrait only)

## Build & Development

This project uses **DevEco Studio** with the **hvigor** build system (`.hvigor` directory). There is no CLI build command outside DevEco.

```bash
# Build via hvigor CLI (if installed)
hvigor assembleHap

# Install dependencies
ohpm install
```

The project targets `@ohos/hypium` 1.0.19 for testing. No test source files exist yet (`entry/src/ohosTest/` is empty).

## Architecture

### Single-Page Navigation

The app has one route (`pages/Index`). `Index.ets` acts as a **router shell** — it conditionally renders sub-pages by toggling `@State` boolean flags:

- `showCardDetailPage` → `CardDetailPage`
- `showPhysicalCardManagerPage` → `PhysicalCardManagerPage`
- `showLanguagePage` → `LanguagePage`
- `showMockSettingsPage` → `MockSettingsPage`
- `currentIndex === 0` → `CardsPage` (default)
- `currentIndex !== 0` → `ProfilePage`

The `BottomNavBar` is hidden when a sub-page is active.

### State Management: CardStore (Singleton)

`CardStore` is the central `@Observed` state holder, accessed via `CardStore.getInstance()`. It holds all runtime state (`cards`, `authorizations`, `physicalCards`, `credentials`, discovery/connection state) and delegates to service interfaces. UI components receive the store via `@ObjectLink` or direct prop passing and react to changes through ArkUI's `@Observed`/`@ObjectLink` reactivity.

### Service Interfaces + Mock Implementation

All business logic is defined through service interfaces in `entry/src/main/ets/services/`:

| Interface | Purpose |
|---|---|
| `DigitalCardService` | CRUD for digital cards |
| `AuthorizationService` | List/get authorizations |
| `PhysicalCardService` | Discovery, connection, credential write/remove on physical cards |
| `CredentialService` | Credential translation, verification |
| `ConfirmationService` | Secondary verification request management |
| `InvitationService` | Invitation code validation, preview, redemption |

`MockDataSource` implements **all** service interfaces in a single class. It is the sole data source — there is no network or native backend. It simulates physical card operations with configurable delays and failure modes (`MockPhysicalCardFailureMode`, `MockDiscoveryScenario`).

### Data Flow for Physical Card Operations

1. `CardStore.startPhysicalCardDiscovery()` → `PhysicalCardService.startDiscovery()` (callback-based)
2. `CardStore.connectPhysicalCard()` → async connection with state tracking
3. `CardStore.writeCardToPrimaryPhysicalCard()` → translate Authorization → Credential → write to physical card → verify → persist
4. State is persisted via `MockPersistenceService` (two implementations: `MockAppStoragePersistence` for production mock, `InMemoryMockPersistence` for testing)

### Invitation Flow

Invitation codes follow format `SLE-XXXX-XXXX` (13 chars). The flow is: validate format → preview (fetch authorization details) → redeem (create authorization + digital card). `InvitationFlowState` tracks the multi-step state machine. Mock invitation codes are predefined in `MockDataSource` (e.g., `SLE-DEMO-2026`, `SLE-LAB2-2026`).

### SLE Verification Requests

External apps can trigger a secondary verification dialog via `EntryAbility.handleSleVerificationRequest()` or through `Want` parameters. `VerificationRequestService` publishes a notification that deep-links back to the app. The verification UI is a slide-to-confirm overlay in `Index.ets`.

### Theme System

`Theme.ets` exports all design tokens (colors, typography, spacing, radii) as constants — it implements a "Luminous Interface" / Google Stitch-inspired design system. Always use theme constants rather than hardcoded values.

### Models

Models are in `entry/src/main/ets/models/`. Key domain objects:

- `DigitalCard` — user-facing card with status, visual style, binding state
- `Authorization` — issuer-granted permission with scopes, usage limits, alert policies
- `Credential` — on-card representation of an authorization, with integrity checks
- `PhysicalCard` — represents a WS63 physical card with capacity and connection state
- `ConfirmationRequest` — secondary verification checkpoint request
- `Invitation` / `MockInvitation` — invitation code and its preview/redemption data

## Coding Conventions

- ArkUI component files use `.ets` extension (Extended TypeScript for ArkUI)
- Service interfaces are pure `.ets` files with `export interface`
- All `forEach` loops use explicit typed callbacks (no arrow functions in some older patterns)
- `@State`, `@StorageLink`, `@Observed`, `@ObjectLink` are ArkUI state decorators — understand their reactivity semantics before modifying
- Bilingual strings are handled inline with ternary expressions (`this.language === 'zh' ? '...' : '...'`), not a i18n framework
- The `MockDataSource` uses manual deep-clone methods (e.g., `cloneCard`, `cloneCredential`) — these must be updated when model fields change
- `AppStorage` / `PersistentStorage` are used for cross-component state and persistence (HarmonyOS built-in)
