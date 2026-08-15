import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ConfirmationRequest } from '../models/ConfirmationRequest'
import { MobilePairRequest, MobileSession } from '../models/MobileSession'
import {
  emptyWalletPersistenceState,
  WalletPersistenceState
} from '../models/WalletPersistence'
import { AssetTokenStore, InMemoryTokenStore } from '../security/TokenStore'
import {
  BackendConfigService,
  DEFAULT_BACKEND_BASE_URL
} from '../services/BackendConfigService'
import { HarmonyHttpTransport } from '../services/HarmonyHttpTransport'
import { MobileApiClient } from '../services/MobileApiClient'
import { MobileWebSocketClient } from '../services/MobileWebSocketClient'
import { MobileWebSocketRouter } from '../services/MobileWebSocketRouter'
import { PreferencesConfirmationPersistence } from '../services/PreferencesConfirmationPersistence'
import { PreferencesWalletPersistence } from '../services/PreferencesWalletPersistence'
import { UnavailableCardCService } from '../services/UnavailableCardCService'
import { CardStore } from '../stores/CardStore'
import { ConfirmationStore } from '../stores/ConfirmationStore'
import { SessionStore } from '../stores/SessionStore'
import { DEFAULT_RUNTIME_MODE, RuntimeMode } from './RuntimeConfig'

export class MobileRuntime {
  private static apiClient: MobileApiClient | null = null
  private static sessionStore: SessionStore | null = null
  private static webSocketClient: MobileWebSocketClient | null = null
  private static webSocketRouter: MobileWebSocketRouter | null = null
  private static context: common.UIAbilityContext | null = null
  private static backendBaseUrl: string = DEFAULT_BACKEND_BASE_URL
  private static initialized: boolean = false

  static async initialize(
    context: common.UIAbilityContext,
    backendAddressOverride: string = ''
  ): Promise<void> {
    MobileRuntime.initialized = false
    MobileRuntime.context = context
    if (DEFAULT_RUNTIME_MODE === RuntimeMode.MOCK) {
      CardStore.getInstance()
      ConfirmationStore.getInstance()
      return
    }

    const backendConfig: BackendConfigService = new BackendConfigService(context)
    try {
      if (backendAddressOverride.length > 0) {
        MobileRuntime.backendBaseUrl =
          await backendConfig.saveBaseUrl(backendAddressOverride)
      } else {
        MobileRuntime.backendBaseUrl = await backendConfig.loadBaseUrl()
      }
    } catch (error) {
      MobileRuntime.backendBaseUrl = DEFAULT_BACKEND_BASE_URL
      hilog.warn(0x0000, 'SleKey', 'Backend address configuration is unavailable.')
    }

    const persistence: PreferencesWalletPersistence =
      new PreferencesWalletPersistence(context)
    let cachedState: WalletPersistenceState = emptyWalletPersistenceState()
    try {
      cachedState = await persistence.load()
    } catch (error) {
      hilog.warn(0x0000, 'SleKey', 'Wallet cache is unavailable; starting empty.')
    }
    let sessionStore: SessionStore = new SessionStore(new AssetTokenStore())
    try {
      await sessionStore.initialize()
    } catch (error) {
      // Some development devices expose AssetStoreKit but reject access for
      // debug-signed applications. Keep the token process-local in that case:
      // pairing remains functional without persisting secrets in Preferences.
      sessionStore = new SessionStore(new InMemoryTokenStore())
      await sessionStore.initialize()
      hilog.warn(0x0000, 'SleKey',
        'Secure session storage is unavailable; using volatile in-memory session.')
    }
    const apiClient: MobileApiClient = new MobileApiClient(
      new HarmonyHttpTransport(MobileRuntime.backendBaseUrl),
      sessionStore
    )
    const unavailableCardCService: UnavailableCardCService =
      new UnavailableCardCService()
    MobileRuntime.apiClient = apiClient
    MobileRuntime.sessionStore = sessionStore
    CardStore.configure({
      cardService: apiClient,
      authorizationService: apiClient,
      invitationService: apiClient,
      physicalCardService: unavailableCardCService,
      credentialService: unavailableCardCService,
      backendService: apiClient,
      persistenceService: persistence,
      cachedState: cachedState,
      initialPhysicalCards: [],
      initialCredentials: []
    })
    CardStore.getInstance().recoverPendingWriteReceipts().catch(() => {
      hilog.warn(0x0000, 'SleKey', 'Pending Card C receipt recovery failed.')
    })

    const confirmationStore: ConfirmationStore =
      ConfirmationStore.configureProduction(
        apiClient,
        new PreferencesConfirmationPersistence(context)
      )
    await confirmationStore.initialize()

    const router: MobileWebSocketRouter = new MobileWebSocketRouter(
      sessionStore.subjectId(),
      async (request: ConfirmationRequest) => {
        try {
          await confirmationStore.receiveProductionRequest(request)
        } catch (error) {
          hilog.warn(0x0000, 'SleKey', 'Unable to persist pushed confirmation.')
        }
      },
      async (cardId: string, serverRevision: string) => {
        try {
          await CardStore.getInstance().refresh()
        } catch (error) {
          hilog.warn(0x0000, 'SleKey', 'Unable to refresh pushed card state.')
        }
      }
    )
    MobileRuntime.webSocketRouter = router
    MobileRuntime.webSocketClient = new MobileWebSocketClient(
      MobileRuntime.backendBaseUrl,
      sessionStore,
      router,
      () => {
        confirmationStore.recoverPending().catch(() => {
          hilog.warn(0x0000, 'SleKey', 'WebSocket pending recovery failed.')
        })
      }
    )
    MobileRuntime.initialized = true
    if (sessionStore.hasUsableSession()) {
      MobileRuntime.webSocketClient.start()
    }
  }

  static async pair(request: MobilePairRequest): Promise<MobileSession> {
    if (!MobileRuntime.apiClient) {
      throw new Error('Production mobile runtime is not initialized')
    }
    const session: MobileSession = await MobileRuntime.apiClient.pair(request)
    hilog.info(0x0000, 'SleKey', 'Mobile pairing session accepted.')
    MobileRuntime.webSocketRouter?.setSubjectId(session.subjectId || '')
    await CardStore.getInstance().refresh()
    hilog.info(0x0000, 'SleKey', 'Mobile wallet refresh completed after pairing.')
    await ConfirmationStore.getInstance().recoverPending()
    hilog.info(0x0000, 'SleKey', 'Mobile confirmation recovery completed after pairing.')
    MobileRuntime.webSocketClient?.start()
    return session
  }

  static async configureBackendAddress(value: string): Promise<void> {
    if (!MobileRuntime.context) {
      throw new Error('Mobile runtime is not initialized')
    }
    const service: BackendConfigService =
      new BackendConfigService(MobileRuntime.context)
    await service.saveBaseUrl(value)
    await MobileRuntime.dispose()
    await MobileRuntime.initialize(MobileRuntime.context)
  }

  static onForeground(): void {
    if (DEFAULT_RUNTIME_MODE === RuntimeMode.MOCK ||
      !MobileRuntime.initialized || !MobileRuntime.apiClient) {
      return
    }
    CardStore.getInstance().refresh().catch(() => {
      hilog.warn(0x0000, 'SleKey', 'Foreground wallet refresh failed.')
    })
    ConfirmationStore.getInstance().recoverPending().catch(() => {
      hilog.warn(0x0000, 'SleKey', 'Foreground confirmation recovery failed.')
    })
    CardStore.getInstance().recoverPendingWriteReceipts().catch(() => {
      hilog.warn(0x0000, 'SleKey', 'Foreground Card C receipt recovery failed.')
    })
    MobileRuntime.webSocketClient?.start()
  }

  static onBackground(): void {
    MobileRuntime.webSocketClient?.stop().catch(() => {
      hilog.warn(0x0000, 'SleKey', 'WebSocket background stop failed.')
    })
  }

  static async dispose(): Promise<void> {
    MobileRuntime.initialized = false
    if (MobileRuntime.webSocketClient) {
      await MobileRuntime.webSocketClient.stop()
    }
    MobileRuntime.webSocketClient = null
    MobileRuntime.webSocketRouter = null
  }
}
