#ifndef SLE_HW_TYPES_H
#define SLE_HW_TYPES_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    HW_EVENT_IDLE = 0,
    HW_EVENT_APPROACHING,
    HW_EVENT_IN_ZONE,
    HW_EVENT_COMPLETED,
    HW_EVENT_CANCELLED,
    HW_EVENT_COOLDOWN
} hw_event_state_t;

typedef enum {
    HW_AUTH_UNKNOWN = 0,
    HW_AUTHORIZED,
    HW_UNAUTHORIZED,
    HW_KEY_FAILED,
    HW_REPLAY_SUSPECTED
} hw_auth_result_t;

typedef enum {
    HW_CONFIRM_NOT_REQUIRED = 0,
    HW_CONFIRM_PENDING,
    HW_CONFIRM_APPROVED,
    HW_CONFIRM_REJECTED,
    HW_CONFIRM_TIMEOUT,
    HW_CONFIRM_OFFLINE
} hw_confirm_state_t;

typedef enum {
    HW_EXEC_NOT_REQUESTED = 0,
    HW_EXEC_PENDING,
    HW_EXEC_SUCCESS,
    HW_EXEC_FAILED
} hw_execution_state_t;

typedef enum {
    HW_ACTION_RECORD = 0,
    HW_ACTION_WAIT_CONFIRM,
    HW_ACTION_EXECUTE,
    HW_ACTION_DENY,
    HW_ACTION_ALERT
} hw_action_t;

typedef enum {
    HW_DIRECTION_UNKNOWN = 0,
    HW_DIRECTION_ENTER,
    HW_DIRECTION_EXIT
} hw_direction_t;

typedef struct {
    uint32_t permission_id;
    uint32_t policy_version;
    bool allow_offline;
    bool allow_execution;
    bool admin_confirm_required;
} hw_permission_summary_t;

typedef struct {
    uint32_t event_id;
    uint32_t source_id;
    uint32_t boot_id;
    uint32_t card_anon_id;
    uint32_t timestamp_ms;
    uint16_t distance_cm;
    uint8_t confidence;
    hw_direction_t direction;
    hw_event_state_t state;
    hw_auth_result_t auth;
    uint32_t auth_session_id;
    uint32_t permission_id;
    uint32_t auth_counter;
} hw_passage_event_t;

#endif
