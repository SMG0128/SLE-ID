#ifndef SLE_DETECTOR_A_CORE_H
#define SLE_DETECTOR_A_CORE_H

#include "ab_messages.h"
#include "ab_protocol.h"
#include "passage_fsm.h"

typedef bool (*detector_a_tx_fn)(const uint8_t *data, size_t length, void *user);
typedef void (*detector_a_decision_fn)(const ab_decision_t *decision, void *user);

#define DETECTOR_A_ACK_TIMEOUT_MS 500U
#define DETECTOR_A_MAX_RETRIES 3U

typedef struct {
    passage_fsm_t passage;
    ab_stream_parser_t parser;
    detector_a_tx_fn tx;
    detector_a_decision_fn on_decision;
    void *user;
    uint32_t source_id;
    uint32_t boot_id;
    uint32_t next_message_id;
    uint32_t next_event_id;
    uint32_t card_anon_id;
    hw_auth_result_t simulated_auth;
    uint32_t auth_session_id;
    uint32_t auth_permission_id;
    uint32_t auth_counter;
    uint32_t last_event_id;
    ab_decision_t last_decision;
    uint32_t sent_events;
    uint32_t send_failures;
    uint32_t acknowledged_events;
    uint32_t retry_attempts;
    uint32_t retry_exhausted;
    uint32_t busy_drops;
    bool pending_active;
    uint8_t pending_frame[AB_MAX_FRAME];
    size_t pending_length;
    uint32_t pending_message_id;
    uint32_t pending_event_id;
    uint32_t pending_sent_ms;
    uint8_t pending_retries;
    bool pending_ack_received;
} detector_a_t;

void detector_a_init(detector_a_t *detector, detector_a_tx_fn tx,
                     detector_a_decision_fn on_decision, void *user);
passage_result_t detector_a_observe(detector_a_t *detector, const passage_observation_t *observation,
                                    uint32_t now_ms);
void detector_a_receive(detector_a_t *detector, const uint8_t *data, size_t length);
void detector_a_set_auth(detector_a_t *detector, hw_auth_result_t auth);
bool detector_a_set_auth_result(detector_a_t *detector, const ab_auth_result_t *result);
void detector_a_set_identity(detector_a_t *detector, uint32_t source_id, uint32_t boot_id);
void detector_a_tick(detector_a_t *detector, uint32_t now_ms);

#endif
