import type { NextFunction, Request, Response } from 'express'

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message)
  }
}

export function ok<T>(res: Response, data: T, message = 'ok'): void {
  res.json({ code: 0, message, data })
}

export function asyncRoute(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction) => {
    void handler(req, res, next).catch(next)
  }
}

export function notFound(req: Request, _res: Response, next: NextFunction): void {
  next(new ApiError(404, 1002, `资源不存在: ${req.method} ${req.path}`))
}

export function errorHandler(error: unknown, _req: Request, res: Response, _next: NextFunction): void {
  if (error instanceof ApiError) {
    res.status(error.status).json({ code: error.code, message: error.message, data: error.details ?? null })
    return
  }
  if (error instanceof SyntaxError && 'status' in error && error.status === 400) {
    res.status(400).json({ code: 1001, message: 'JSON 请求体格式错误', data: null })
    return
  }
  const message = error instanceof Error ? error.message : '服务器内部错误'
  console.error('[server]', error)
  res.status(500).json({ code: 5000, message, data: null })
}
