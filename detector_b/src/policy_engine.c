#include "policy_engine.h"

hw_action_t policy_decide(const hw_permission_summary_t *permission,
                          const hw_policy_input_t *input) {
    if (input->auth != HW_AUTHORIZED) return input->alert_on_denial ? HW_ACTION_ALERT : HW_ACTION_DENY;
    if (!input->backend_online && !permission->allow_offline) return HW_ACTION_DENY;
    if (permission->admin_confirm_required || input->user_confirm_enabled) return HW_ACTION_WAIT_CONFIRM;
    return permission->allow_execution ? HW_ACTION_EXECUTE : HW_ACTION_RECORD;
}
