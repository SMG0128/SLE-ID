import {
  DetectorId,
  EventId,
  PermissionId,
  RequestId
} from './DomainIdentifiers'

export enum ConfirmationRequestStatus {
  NOT_REQUIRED = 'notRequired',
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  TIMEOUT = 'timeout',
  OFFLINE = 'offline'
}

export enum ConfirmationDirection {
  ENTRY = 'entry',
  EXIT = 'exit',
  UNKNOWN = 'unknown'
}

export enum ConfirmationTransitionReason {
  NONE = 'none',
  EXPIRED = 'expired',
  TERMINAL = 'terminal',
  INVALID = 'invalid'
}

export interface ConfirmationRequest {
  requestId: RequestId
  digitalCardId: string
  permissionId: PermissionId
  detectorId: DetectorId
  checkpointName: string
  eventId: EventId
  action: string
  direction: ConfirmationDirection
  randomCode: string
  readonly adminConfirmRequired: boolean
  status: ConfirmationRequestStatus
  createdAt: string
  expiresAt: string
  resolvedAt: string
}

export interface ConfirmationTransitionResult {
  accepted: boolean
  reason: ConfirmationTransitionReason
  request: ConfirmationRequest
}

export function isTerminalConfirmationStatus(
  status: ConfirmationRequestStatus
): boolean {
  return status === ConfirmationRequestStatus.NOT_REQUIRED ||
    status === ConfirmationRequestStatus.APPROVED ||
    status === ConfirmationRequestStatus.REJECTED ||
    status === ConfirmationRequestStatus.TIMEOUT ||
    status === ConfirmationRequestStatus.OFFLINE
}

export function transitionConfirmationRequest(
  request: ConfirmationRequest,
  nextStatus: ConfirmationRequestStatus,
  resolvedAt: string
): ConfirmationTransitionResult {
  if (request.status === nextStatus &&
    isTerminalConfirmationStatus(request.status)) {
    return {
      accepted: true,
      reason: ConfirmationTransitionReason.NONE,
      request: cloneConfirmationRequest(request)
    }
  }
  if (isTerminalConfirmationStatus(request.status)) {
    return {
      accepted: false,
      reason: ConfirmationTransitionReason.TERMINAL,
      request: cloneConfirmationRequest(request)
    }
  }
  if (request.status !== ConfirmationRequestStatus.PENDING ||
    nextStatus === ConfirmationRequestStatus.PENDING) {
    return {
      accepted: false,
      reason: ConfirmationTransitionReason.INVALID,
      request: cloneConfirmationRequest(request)
    }
  }
  if (nextStatus === ConfirmationRequestStatus.APPROVED &&
    Date.parse(resolvedAt) >= Date.parse(request.expiresAt)) {
    const timedOut: ConfirmationRequest = cloneConfirmationRequest(request)
    timedOut.status = ConfirmationRequestStatus.TIMEOUT
    timedOut.resolvedAt = resolvedAt
    return {
      accepted: false,
      reason: ConfirmationTransitionReason.EXPIRED,
      request: timedOut
    }
  }
  const resolved: ConfirmationRequest = cloneConfirmationRequest(request)
  resolved.status = nextStatus
  resolved.resolvedAt = resolvedAt
  return {
    accepted: true,
    reason: ConfirmationTransitionReason.NONE,
    request: resolved
  }
}

export function cloneConfirmationRequest(
  request: ConfirmationRequest
): ConfirmationRequest {
  return {
    requestId: request.requestId,
    digitalCardId: request.digitalCardId,
    permissionId: request.permissionId,
    detectorId: request.detectorId,
    checkpointName: request.checkpointName,
    eventId: request.eventId,
    action: request.action,
    direction: request.direction,
    randomCode: request.randomCode,
    adminConfirmRequired: request.adminConfirmRequired === true,
    status: request.status,
    createdAt: request.createdAt,
    expiresAt: request.expiresAt,
    resolvedAt: request.resolvedAt
  }
}
