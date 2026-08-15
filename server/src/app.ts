import fs from 'node:fs'
import path from 'node:path'
import express, { type Express } from 'express'
import type { AppConfig } from './config.js'
import type { StarFollowDatabase } from './db.js'
import { errorHandler, notFound } from './http.js'
import { createApiRouter } from './routes/api.js'
import { createMobileRouter } from './routes/mobile.js'
import type { HardwareService } from './services/hardware.js'
import { apiAuthentication } from './auth.js'

export function createApp(config: AppConfig, db: StarFollowDatabase, hardware: HardwareService): Express {
  const app = express()
  app.disable('x-powered-by')
  app.use(express.json({ limit: '256kb' }))
  app.use('/api/mobile', createMobileRouter(config, db, hardware))
  app.use('/api', apiAuthentication(config), createApiRouter(db, hardware))

  if (fs.existsSync(config.frontendDist)) {
    app.use(express.static(config.frontendDist, { index: false, maxAge: '1h' }))
    app.get(/^(?!\/api|\/ws).*/, (_req, res) => res.sendFile(path.join(config.frontendDist, 'index.html')))
  }

  app.use(notFound)
  app.use(errorHandler)
  return app
}
