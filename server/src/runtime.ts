import { createServer, type Server as HttpServer } from 'node:http'
import { createApp } from './app.js'
import type { AppConfig } from './config.js'
import { StarFollowDatabase } from './db.js'
import { HardwareService } from './services/hardware.js'
import { WsHub } from './ws/hub.js'
import { MobileSessionStore } from './services/mobileSessions.js'
import { GatewaySerial } from './ws63/gateway.js'
import { assertSafeNetworkConfig } from './config.js'

export interface Runtime {
  config: AppConfig
  db: StarFollowDatabase
  gateway: GatewaySerial
  hardware: HardwareService
  server: HttpServer
  hub: WsHub
  start(): Promise<void>
  stop(): Promise<void>
}

export function createRuntime(config: AppConfig): Runtime {
  assertSafeNetworkConfig(config)
  const db = new StarFollowDatabase(config.databasePath)
  const storedSourceId = db.getSetting<number>('hostSourceId')
  const hostSourceId = config.hostSourceIdOverride ? config.hostSourceId : (storedSourceId ?? config.hostSourceId)
  if (storedSourceId !== hostSourceId) db.setSetting('hostSourceId', hostSourceId)
  const gateway = new GatewaySerial(hostSourceId, config.hostBootId)
  const hardware = new HardwareService(gateway, db)
  const mobileSessions = new MobileSessionStore()
  const app = createApp(config, db, hardware, mobileSessions)
  const server = createServer(app)
  const hub = new WsHub(server, config.apiToken, mobileSessions)
  hardware.attachHub(hub)
  let maintenanceTimer: NodeJS.Timeout | null = null
  let maintenanceTask: Promise<void> = Promise.resolve()

  const scheduleMaintenance = () => {
    maintenanceTask = maintenanceTask.then(async () => {
      if (!db.raw.name || db.raw.name === ':memory:') return
      const today = new Date().toISOString().slice(0, 10)
      const lastBackup = db.getSetting<string>('lastBackup')
      if (lastBackup?.slice(0, 10) === today) return
      await db.createBackup('system')
    }).catch(error => {
      console.error('[maintenance] daily database backup failed', error)
    })
  }

  return {
    config,
    db,
    gateway,
    hardware,
    server,
    hub,
    async start() {
      const recovered = db.recoverInterruptedConfirmations()
      if (recovered.requeued > 0 || recovered.expired > 0) {
        console.log(`[server] recovered confirmations: pending=${recovered.requeued}, expired=${recovered.expired}`)
      }
      await new Promise<void>((resolve, reject) => {
        server.once('error', reject)
        server.listen(config.port, config.host, () => {
          server.off('error', reject)
          resolve()
        })
      })
      await hardware.start()
      scheduleMaintenance()
      maintenanceTimer = setInterval(scheduleMaintenance, 60 * 60 * 1000)
      maintenanceTimer.unref()
    },
    async stop() {
      if (maintenanceTimer) clearInterval(maintenanceTimer)
      maintenanceTimer = null
      await hardware.stop()
      await hub.close()
      await new Promise<void>(resolve => server.close(() => resolve()))
      await maintenanceTask
      db.close()
    },
  }
}
