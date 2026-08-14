import { loadConfig } from './config.js'
import { createRuntime } from './runtime.js'

const config = loadConfig()
const runtime = createRuntime(config)
let stopping = false

async function shutdown(signal: string): Promise<void> {
  if (stopping) return
  stopping = true
  console.log(`[server] ${signal}, shutting down...`)
  try {
    await runtime.stop()
    process.exitCode = 0
  } catch (error) {
    console.error('[server] shutdown failed', error)
    process.exitCode = 1
  }
}

process.on('SIGINT', () => void shutdown('SIGINT'))
process.on('SIGTERM', () => void shutdown('SIGTERM'))

runtime.start().then(() => {
  console.log(`[server] StarFollow backend listening at http://${config.host}:${config.port}`)
  console.log(`[server] SQLite: ${config.databasePath}`)
  if (!runtime.gateway.snapshot().port) console.log('[server] serial is not configured; select Detector B COM port in system settings')
}).catch(error => {
  console.error('[server] startup failed', error)
  process.exitCode = 1
})
