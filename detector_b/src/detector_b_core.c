#include "detector_b_core.h"

#include <string.h>

#define DETECTOR_B_DEFAULT_SOURCE_ID 0xB0000001U
#define DETECTOR_B_CONFIRM_TIMEOUT_MS 10000U

static ab_frame_header_t make_header(detector_b_t *detector, uint8_t type, uint8_t flags)
{
    ab_frame_header_t header;
    header.type = type;
    header.flags = flags;
    header.source_role = AB_ROLE_DETECTOR_B;
    header.source_id = detector->source_id;
    header.boot_id = detector->boot_id;
    header.message_id = detector->next_message_id++;
    return header;
}

static ab_reason_t auth_reason(hw_auth_result_t auth)
{
    if (auth == HW_KEY_FAILED) return AB_REASON_KEY_FAILED;
    if (auth == HW_REPLAY_SUSPECTED) return AB_REASON_REPLAY_SUSPECTED;
    return AB_REASON_NO_PERMISSION;
}

static detector_b_event_key_t *find_event(detector_b_t *detector, uint32_t source_id,
                                          uint32_t boot_id, uint32_t event_id)
{
    size_t i;
    for (i = 0U; i < DETECTOR_B_DEDUP_WINDOW; ++i) {
        detector_b_event_key_t *key = &detector->recent_events[i];
        if (key->valid && key->source_id == source_id && key->boot_id == boot_id &&
            key->event_id == event_id) {
            return key;
        }
    }
    return NULL;
}

static void remember_event(detector_b_t *detector, const hw_passage_event_t *event)
{
    detector_b_event_key_t *key = &detector->recent_events[detector->recent_event_cursor];
    (void)memset(key, 0, sizeof(*key));
    key->valid = true;
    key->source_id = event->source_id;
    key->boot_id = event->boot_id;
    key->event_id = event->event_id;
    detector->recent_event_cursor =
        (uint8_t)((detector->recent_event_cursor + 1U) % DETECTOR_B_DEDUP_WINDOW);
}

static void send_ack(detector_b_t *detector, uint32_t message_id, ab_ack_status_t status)
{
    uint8_t payload[AB_MAX_PAYLOAD];
    uint8_t frame[AB_MAX_FRAME];
    ab_ack_t ack;
    ab_frame_header_t header = make_header(detector, AB_MSG_ACK, AB_FLAG_RESPONSE);
    size_t payload_len;
    size_t frame_len;
    ack.message_id = message_id;
    ack.status = status;
    payload_len = ab_ack_encode(&ack, payload, sizeof(payload));
    frame_len = ab_frame_encode(&header, payload, (uint16_t)payload_len, frame, sizeof(frame));
    if (detector->tx == NULL || frame_len == 0U || !detector->tx(frame, frame_len, detector->user))
        detector->ack_send_failures++;
}

static void transmit_decision(detector_b_t *detector, const ab_decision_t *decision,
                              bool retry)
{
    uint8_t payload[AB_MAX_PAYLOAD];
    uint8_t frame[AB_MAX_FRAME];
    ab_frame_header_t header = make_header(detector, AB_MSG_DECISION, 0U);
    size_t payload_len = ab_decision_encode(decision, payload, sizeof(payload));
    size_t frame_len = ab_frame_encode(&header, payload, (uint16_t)payload_len,
                                       frame, sizeof(frame));
    if (detector->tx != NULL && frame_len != 0U && detector->tx(frame, frame_len, detector->user))
        detector->decisions_sent++;
    else
        detector->decision_send_failures++;
    if (retry) detector->decision_retries++;
}

static void send_decision(detector_b_t *detector, const hw_passage_event_t *event,
                          ab_decision_t *decision)
{
    detector_b_event_key_t *key = find_event(detector, event->source_id,
                                              event->boot_id, event->event_id);
    if (key != NULL) {
        key->decision_valid = true;
        key->decision = *decision;
    }
    transmit_decision(detector, decision, false);
    if (detector->report != NULL) detector->report(event, decision, detector->user);
}

static void finish_event(detector_b_t *detector, const hw_passage_event_t *event,
                         hw_action_t action, hw_confirm_state_t confirm, uint32_t now_ms)
{
    ab_decision_t decision;
    (void)memset(&decision, 0, sizeof(decision));
    decision.event_id = event->event_id;
    decision.action = action;
    decision.confirm = confirm;
    decision.timestamp_ms = now_ms;
    if (action == HW_ACTION_EXECUTE) {
        decision.execution = HW_EXEC_PENDING;
        if (detector->actuator != NULL && detector->actuator(event->event_id, detector->user))
            decision.execution = HW_EXEC_SUCCESS;
        else {
            decision.execution = HW_EXEC_FAILED;
            decision.reason = AB_REASON_EXECUTION_FAILED;
        }
    } else {
        decision.execution = HW_EXEC_NOT_REQUESTED;
        if (action == HW_ACTION_DENY && event->auth == HW_AUTHORIZED &&
            !detector->policy_input.backend_online && !detector->permission.allow_offline)
            decision.reason = AB_REASON_BACKEND_OFFLINE;
        else if (action == HW_ACTION_DENY || action == HW_ACTION_ALERT)
            decision.reason = auth_reason(event->auth);
    }
    send_decision(detector, event, &decision);
}

static void send_busy_decision(detector_b_t *detector, const hw_passage_event_t *event)
{
    ab_decision_t decision;
    (void)memset(&decision, 0, sizeof(decision));
    decision.event_id = event->event_id;
    decision.action = HW_ACTION_DENY;
    decision.confirm = HW_CONFIRM_NOT_REQUIRED;
    decision.execution = HW_EXEC_NOT_REQUESTED;
    decision.reason = AB_REASON_BUSY;
    decision.timestamp_ms = detector->receive_now_ms;
    detector->busy_events++;
    send_decision(detector, event, &decision);
}

static void on_frame(const ab_frame_t *frame, void *user)
{
    detector_b_t *detector = (detector_b_t *)user;
    hw_passage_event_t event;
    hw_action_t action;
    ab_decision_t decision;
    if (frame->header.type != AB_MSG_PASSAGE_EVENT) return;
    if (frame->header.source_role != AB_ROLE_DETECTOR_A ||
        !ab_passage_decode(frame->payload, frame->payload_length, &event)) {
        detector->malformed_events++;
        if ((frame->header.flags & AB_FLAG_ACK_REQUIRED) != 0U)
            send_ack(detector, frame->header.message_id, AB_ACK_BAD_MESSAGE);
        return;
    }
    event.source_id = frame->header.source_id;
    event.boot_id = frame->header.boot_id;
    {
        detector_b_event_key_t *existing = find_event(detector, event.source_id,
                                                       event.boot_id, event.event_id);
        if (existing != NULL) {
            detector->duplicate_events++;
            if ((frame->header.flags & AB_FLAG_ACK_REQUIRED) != 0U)
                send_ack(detector, frame->header.message_id, AB_ACK_DUPLICATE);
            if (existing->decision_valid)
                transmit_decision(detector, &existing->decision, true);
            return;
        }
    }
    remember_event(detector, &event);
    detector->received_events++;
    if ((frame->header.flags & AB_FLAG_ACK_REQUIRED) != 0U)
        send_ack(detector, frame->header.message_id, AB_ACK_ACCEPTED);
    event.auth = detector->authorize_event != NULL &&
                 detector->authorize_event(&event, detector->user) &&
                 event.permission_id == detector->permission.permission_id ?
                 HW_AUTHORIZED : HW_UNAUTHORIZED;
    if (detector->pending_valid) {
        send_busy_decision(detector, &event);
        return;
    }
    detector->policy_input.auth = event.auth;
    action = policy_decide(&detector->permission, &detector->policy_input);
    if (action == HW_ACTION_WAIT_CONFIRM) {
        detector->pending_valid = true;
        detector->pending_event = event;
        detector->confirm_deadline_ms = detector->receive_now_ms + DETECTOR_B_CONFIRM_TIMEOUT_MS;
        (void)memset(&decision, 0, sizeof(decision));
        decision.event_id = event.event_id;
        decision.action = action;
        decision.confirm = HW_CONFIRM_PENDING;
        decision.execution = HW_EXEC_NOT_REQUESTED;
        decision.timestamp_ms = detector->receive_now_ms;
        send_decision(detector, &event, &decision);
        return;
    }
    finish_event(detector, &event, action, HW_CONFIRM_NOT_REQUIRED, detector->receive_now_ms);
}

void detector_b_init(detector_b_t *detector, detector_b_tx_fn tx,
                     detector_b_actuator_fn actuator, detector_b_report_fn report, void *user)
{
    if (detector == NULL) return;
    (void)memset(detector, 0, sizeof(*detector));
    ab_parser_init(&detector->parser, on_frame, detector);
    detector->tx = tx;
    detector->actuator = actuator;
    detector->report = report;
    detector->user = user;
    detector->source_id = DETECTOR_B_DEFAULT_SOURCE_ID;
    detector->boot_id = 1U;
    detector->next_message_id = 1U;
    detector->permission.permission_id = 1U;
    detector->permission.policy_version = 1U;
    detector->permission.allow_offline = true;
    detector->permission.allow_execution = true;
    detector->policy_input.backend_online = true;
    detector->policy_input.alert_on_denial = true;
}

void detector_b_receive(detector_b_t *detector, const uint8_t *data, size_t length, uint32_t now_ms)
{
    if (detector == NULL) return;
    detector->receive_now_ms = now_ms;
    ab_parser_feed(&detector->parser, data, length);
}

bool detector_b_confirm(detector_b_t *detector, bool approved, uint32_t now_ms)
{
    hw_passage_event_t event;
    if (detector == NULL || !detector->pending_valid) return false;
    if ((int32_t)(now_ms - detector->confirm_deadline_ms) >= 0) {
        detector_b_tick(detector, now_ms);
        return false;
    }
    event = detector->pending_event;
    detector->pending_valid = false;
    if (approved) finish_event(detector, &event, HW_ACTION_EXECUTE, HW_CONFIRM_APPROVED, now_ms);
    else {
        ab_decision_t decision = { event.event_id, HW_ACTION_DENY, HW_CONFIRM_REJECTED,
                                   HW_EXEC_NOT_REQUESTED, AB_REASON_CONFIRM_REJECTED, now_ms };
        send_decision(detector, &event, &decision);
    }
    return true;
}

void detector_b_tick(detector_b_t *detector, uint32_t now_ms)
{
    if (detector != NULL && detector->pending_valid &&
        (int32_t)(now_ms - detector->confirm_deadline_ms) >= 0) {
        hw_passage_event_t event = detector->pending_event;
        ab_decision_t decision = { event.event_id, HW_ACTION_DENY, HW_CONFIRM_TIMEOUT,
                                   HW_EXEC_NOT_REQUESTED, AB_REASON_CONFIRM_TIMEOUT, now_ms };
        detector->pending_valid = false;
        send_decision(detector, &event, &decision);
    }
}

void detector_b_set_identity(detector_b_t *detector, uint32_t source_id, uint32_t boot_id)
{
    if (detector == NULL || source_id == 0U || boot_id == 0U) return;
    detector->source_id = source_id;
    detector->boot_id = boot_id;
}

void detector_b_set_authorizer(detector_b_t *detector,
                               detector_b_authorize_event_fn authorize_event)
{
    if (detector != NULL) detector->authorize_event = authorize_event;
}
