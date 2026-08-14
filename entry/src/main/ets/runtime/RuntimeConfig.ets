export enum RuntimeMode {
  PRODUCTION = 'production',
  MOCK = 'mock'
}

// Development environments may switch this single value to MOCK. Pages never
// branch on runtime mode.
export const DEFAULT_RUNTIME_MODE: RuntimeMode = RuntimeMode.PRODUCTION
