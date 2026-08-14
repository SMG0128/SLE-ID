#ifndef SLE_AB_MESSAGES_H
#define SLE_AB_MESSAGES_H

#include <stddef.h>

#include "hw_types.h"

#define AB_PASSAGE_PAYLOAD_SIZE 30U
#define AB_DECISION_PAYLOAD_SIZE 12U
#define AB_ACK_PAYLOAD_SIZE 5U
#define AB_AUTH_RESULT_PAYLOAD_SIZE 20U

typedef enum {
    AB_REASON_NONE = 0,
    AB_REASON_NO_PERMISSION,
    AB_REASON_OUT_OF_SCOPE,
    AB_REASON_NOT_YET_VALID,
    AB_REASON_EXPIRED,
    AB_REASON_USAGE_EXHAUSTED,
    AB_REASON_FROZEN,
    AB_REASON_LOST,
    AB_REASON_REVOKED,
    AB_REASON_KEY_VERSION_MISMATCH,
    AB_REASON_KEY_FAILED,
    AB_REASON_REPLAY_SUSPECTED,
    AB_REASON_POLICY_STALE,
    AB_REASON_BACKEND_OFFLINE,
    AB_REASON_CONFIRM_REJECTED,
    AB_REASON_CONFIRM_TIMEOUT,
    AB_REASON_CONFIRM_OFFLINE,
    AB_REASON_EXECUTION_FAILED,
    AB_REASON_LINK_LOST,
    AB_REASON_DUPLICATE_EVENT,
    AB_REASON_BUSY,
    AB_REASON_STALE_REQUEST,
    AB_REASON_BAD_MESSAGE
} ab_reason_t;

typedef enum {
    AB_ACK_ACCEPTED = 0,
    AB_ACK_DUPLICATE = 1,
    AB_ACK_BAD_MESSAGE = 2,
    AB_ACK_BUSY = 3
} ab_ack_status_t;

typedef struct {
    uint32_t message_id;
    ab_ack_status_t status;
} ab_ack_t;

typedef struct {
    uint32_t event_id;
    hw_action_t action;
    hw_confirm_state_t confirm;
    hw_execution_state_t execution;
    ab_reason_t reason;
    uint32_t timestamp_ms;
} ab_decision_t;

typedef struct {
    uint32_t session_id;
    uint32_t card_id;
    uint32_t permission_id;
    hw_auth_result_t auth;
    ab_reason_t reason;
    uint32_t counter;
} ab_auth_result_t;

size_t ab_passage_encode(const hw_passage_event_t *event, uint8_t *out, size_t capacity);
bool ab_passage_decode(const uint8_t *data, size_t length, hw_passage_event_t *event);
size_t ab_decision_encode(const ab_decision_t *decision, uint8_t *out, size_t capacity);
bool ab_decision_decode(const uint8_t *data, size_t length, ab_decision_t *decision);
size_t ab_ack_encode(const ab_ack_t *ack, uint8_t *out, size_t capacity);
bool ab_ack_decode(const uint8_t *data, size_t length, ab_ack_t *ack);
size_t ab_auth_result_encode(const ab_auth_result_t *result, uint8_t *out, size_t capacity);
bool ab_auth_result_decode(const uint8_t *data, size_t length, ab_auth_result_t *result);

#endif
