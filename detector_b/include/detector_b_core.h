#ifndef SLE_DETECTOR_B_CORE_H
#define SLE_DETECTOR_B_CORE_H

#include "ab_messages.h"
#include "ab_protocol.h"
#include "policy_engine.h"

typedef bool (*detector_b_tx_fn)(const uint8_t *data, size_t length, void *user);
typedef bool (*detector_b_actuator_fn)(uint32_t event_id, void *user);
typedef void (*detector_b_report_fn)(const hw_passage_event_t *event,
                                     const ab_decision_t *decision, void *user);
typedef bool (*detector_b_authorize_event_fn)(const hw_passage_event_t *event, void *user);

#define DETECTOR_B_DEDUP_WINDOW 32U

typedef struct {
    bool valid;
    uint32_t source_id;
    uint32_t boot_id;
    uint32_t event_id;
    bool decision_valid;
    ab_decision_t decision;
} detector_b_event_key_t;

typedef struct {
    ab_stream_parser_t parser;
    detector_b_tx_fn tx;
    detector_b_actuator_fn actuator;
    detector_b_report_fn report;
    detector_b_authorize_event_fn authorize_event;
    void *user;
    hw_permission_summary_t permission;
    hw_policy_input_t policy_input;
    uint32_t source_id;
    uint32_t boot_id;
    uint32_t next_message_id;
    uint32_t receive_now_ms;
    detector_b_event_key_t recent_events[DETECTOR_B_DEDUP_WINDOW];
    uint8_t recent_event_cursor;
    bool pending_valid;
    hw_passage_event_t pending_event;
    uint32_t confirm_deadline_ms;
    uint32_t received_events;
    uint32_t duplicate_events;
    uint32_t malformed_events;
    uint32_t busy_events;
    uint32_t ack_send_failures;
    uint32_t decision_send_failures;
    uint32_t decisions_sent;
    uint32_t decision_retries;
} detector_b_t;

void detector_b_init(detector_b_t *detector, detector_b_tx_fn tx,
                     detector_b_actuator_fn actuator, detector_b_report_fn report, void *user);
void detector_b_receive(detector_b_t *detector, const uint8_t *data, size_t length, uint32_t now_ms);
bool detector_b_confirm(detector_b_t *detector, bool approved, uint32_t now_ms);
void detector_b_tick(detector_b_t *detector, uint32_t now_ms);
void detector_b_set_identity(detector_b_t *detector, uint32_t source_id, uint32_t boot_id);
void detector_b_set_authorizer(detector_b_t *detector,
                               detector_b_authorize_event_fn authorize_event);

#endif
