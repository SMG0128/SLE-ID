#ifndef SLE_POLICY_ENGINE_H
#define SLE_POLICY_ENGINE_H

#include "hw_types.h"

typedef struct {
    hw_auth_result_t auth;
    bool user_confirm_enabled;
    bool backend_online;
    bool alert_on_denial;
} hw_policy_input_t;

hw_action_t policy_decide(const hw_permission_summary_t *permission,
                          const hw_policy_input_t *input);

#endif
