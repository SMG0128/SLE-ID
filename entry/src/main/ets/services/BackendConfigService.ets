import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

export const DEFAULT_BACKEND_BASE_URL: string = 'http://localhost:3000'

export function normalizeBackendBaseUrl(value: string): string {
  let normalized: string = value.trim()
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  if ((!normalized.startsWith('http://') &&
    !normalized.startsWith('https://')) ||
    normalized.indexOf('@') >= 0) {
    throw new Error('Backend address must be an HTTP(S) URL without credentials')
  }
  return normalized
}

export function mobileWebSocketUrl(baseUrl: string): string {
  const normalized: string = normalizeBackendBaseUrl(baseUrl)
  if (normalized.startsWith('https://')) {
    return `wss://${normalized.substring(8)}/ws/mobile`
  }
  return `ws://${normalized.substring(7)}/ws/mobile`
}

export class BackendConfigService {
  private readonly context: common.UIAbilityContext
  private readonly preferenceName: string = 'sle_id_mobile_runtime'
  private readonly baseUrlKey: string = 'backend_base_url'

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async loadBaseUrl(): Promise<string> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        this.context,
        { name: this.preferenceName }
      )
      const stored: string = await store.get(
        this.baseUrlKey,
        DEFAULT_BACKEND_BASE_URL
      ) as string
      return normalizeBackendBaseUrl(stored)
    } catch (error) {
      throw new Error('Unable to load backend address')
    }
  }

  async saveBaseUrl(value: string): Promise<string> {
    const normalized: string = normalizeBackendBaseUrl(value)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        this.context,
        { name: this.preferenceName }
      )
      await store.put(this.baseUrlKey, normalized)
      await store.flush()
      return normalized
    } catch (error) {
      throw new Error('Unable to save backend address')
    }
  }
}
