import { timingSafeEqual } from 'node:crypto'
import type { NextFunction, Request, Response } from 'express'
import type { IncomingMessage } from 'node:http'
import type { AppConfig } from './config.js'

function safeEqual(left: string, right: string): boolean {
  const a = Buffer.from(left)
  const b = Buffer.from(right)
  return a.length === b.length && timingSafeEqual(a, b)
}

function bearerToken(value: string | string[] | undefined): string | null {
  const text = Array.isArray(value) ? value[0] : value
  const match = typeof text === 'string' ? /^Bearer\s+(.+)$/i.exec(text.trim()) : null
  return match?.[1]?.trim() || null
}

export function requestToken(request: IncomingMessage): string | null {
  const headerToken = request.headers['x-api-token']
  const fromHeader = Array.isArray(headerToken) ? headerToken[0] : headerToken
  if (typeof fromHeader === 'string' && fromHeader.trim()) return fromHeader.trim()
  const bearer = bearerToken(request.headers.authorization)
  if (bearer) return bearer
  try {
    return new URL(request.url || '/', 'http://localhost').searchParams.get('access_token')
  } catch {
    return null
  }
}

export function isAuthorized(request: IncomingMessage, expectedToken?: string): boolean {
  if (!expectedToken) return true
  const actual = requestToken(request)
  return actual !== null && safeEqual(actual, expectedToken)
}

export function apiAuthentication(config: AppConfig) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!isAuthorized(req, config.apiToken)) {
      res.setHeader('WWW-Authenticate', 'Bearer realm="StarFollow"')
      res.status(401).json({ code: 1003, message: '未授权：请提供有效访问令牌', data: null })
      return
    }
    res.locals.authenticatedOperator = config.apiToken ? (config.adminOperator || 'admin') : null
    if (config.apiToken) req.headers['x-operator'] = config.adminOperator || 'admin'
    next()
  }
}
