export interface ConfirmationPolicy {
  readonly adminConfirmRequired: boolean
  userConfirmEnabled: boolean
}

export function finalConfirmRequired(
  adminConfirmRequired: boolean,
  userConfirmEnabled: boolean
): boolean {
  return adminConfirmRequired || userConfirmEnabled
}

export function applyUserConfirmationPreference(
  policy: ConfirmationPolicy,
  requestedEnabled: boolean
): ConfirmationPolicy {
  if (policy.adminConfirmRequired && !requestedEnabled) {
    return {
      adminConfirmRequired: policy.adminConfirmRequired,
      userConfirmEnabled: policy.userConfirmEnabled
    }
  }
  return {
    adminConfirmRequired: policy.adminConfirmRequired,
    userConfirmEnabled: requestedEnabled
  }
}

