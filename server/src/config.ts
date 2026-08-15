import { randomBytes } from 'node:crypto'
import path from 'node:path'

export interface AppConfig {
  host: string
  port: number
  dataDir: string
  databasePath: string
  frontendDist: string
  hostSourceId: number
  hostSourceIdOverride?: boolean
  hostBootId: number
  /** Shared access token for REST and WebSocket. Required outside loopback. */
  apiToken?: string
  /** Audit identity used when token authentication is enabled. */
  adminOperator?: string
  /** Local bootstrap secret used to pair a HarmonyOS mobile client. */
  mobilePairingCode?: string
}

function nonZeroRandomU32(): number {
  const value = randomBytes(4).readUInt32LE(0)
  return value === 0 ? 1 : value
}

function parsePort(value: string | undefined, fallback: number): number {
  const parsed = Number(value)
  return Number.isInteger(parsed) && parsed > 0 && parsed <= 65535 ? parsed : fallback
}

export function loadConfig(cwd = process.cwd()): AppConfig {
  const dataDir = path.resolve(process.env.STARFOLLOW_DATA_DIR || path.join(cwd, 'data'))
  const configuredSourceId = process.env.STARFOLLOW_HOST_SOURCE_ID
  const parsedSourceId = configuredSourceId === undefined ? nonZeroRandomU32() : Number(configuredSourceId) >>> 0
  const apiToken = process.env.STARFOLLOW_API_TOKEN?.trim()
  const config: AppConfig = {
    host: process.env.STARFOLLOW_HOST || '127.0.0.1',
    port: parsePort(process.env.STARFOLLOW_PORT, 8080),
    dataDir,
    databasePath: path.join(dataDir, 'starfollow.db'),
    frontendDist: path.resolve(process.env.STARFOLLOW_FRONTEND_DIST || path.join(cwd, '..', 'StarFollow-Admin', 'dist')),
    hostSourceId: parsedSourceId === 0 ? nonZeroRandomU32() : parsedSourceId,
    hostSourceIdOverride: configuredSourceId !== undefined,
    hostBootId: nonZeroRandomU32(),
    adminOperator: process.env.STARFOLLOW_ADMIN_OPERATOR?.trim() || 'admin',
  }
  if (apiToken) config.apiToken = apiToken
  const mobilePairingCode = process.env.STARFOLLOW_MOBILE_PAIRING_CODE?.trim()
  if (mobilePairingCode) config.mobilePairingCode = mobilePairingCode
  assertSafeNetworkConfig(config)
  return config
}

export function isLoopbackHost(host: string): boolean {
  const normalized = host.trim().toLowerCase().replace(/^\[|\]$/g, '')
  return normalized === 'localhost' || normalized === '::1' || normalized === '0:0:0:0:0:0:0:1' || /^127(?:\.\d{1,3}){3}$/.test(normalized)
}

export function assertSafeNetworkConfig(config: AppConfig): void {
  if (!isLoopbackHost(config.host) && !config.apiToken?.trim()) {
    throw new Error('STARFOLLOW_API_TOKEN is required when STARFOLLOW_HOST is not a loopback address')
  }
}
