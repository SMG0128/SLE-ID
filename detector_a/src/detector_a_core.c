#include "detector_a_core.h"

#include <string.h>

#define DETECTOR_A_DEFAULT_SOURCE_ID 0xA0000001U

static ab_frame_header_t make_header(detector_a_t *detector, uint8_t type, uint8_t flags)
{
    ab_frame_header_t header;
    header.type = type;
    header.flags = flags;
    header.source_role = AB_ROLE_DETECTOR_A;
    header.source_id = detector->source_id;
    header.boot_id = detector->boot_id;
    header.message_id = detector->next_message_id++;
    return header;
}

static void on_frame(const ab_frame_t *frame, void *user)
{
    detector_a_t *detector = (detector_a_t *)user;
    ab_decision_t decision;
    ab_ack_t ack;
    if (frame->header.source_role != AB_ROLE_DETECTOR_B) return;
    if (frame->header.type == AB_MSG_ACK) {
        if (ab_ack_decode(frame->payload, frame->payload_length, &ack) &&
            detector->pending_active && ack.message_id == detector->pending_message_id &&
            (ack.status == AB_ACK_ACCEPTED || ack.status == AB_ACK_DUPLICATE)) {
            if (!detector->pending_ack_received) detector->acknowledged_events++;
            detector->pending_ack_received = true;
        }
        return;
    }
    if (frame->header.type != AB_MSG_DECISION ||
        !ab_decision_decode(frame->payload, frame->payload_length, &decision)) {
        return;
    }
    if (decision.event_id == 0U || decision.event_id != detector->last_event_id) return;
    detector->last_decision = decision;
    if (detector->pending_active && decision.event_id == detector->pending_event_id)
        detector->pending_active = false;
    if (detector->on_decision != NULL) detector->on_decision(&decision, detector->user);
}

void detector_a_init(detector_a_t *detector, detector_a_tx_fn tx,
                     detector_a_decision_fn on_decision, void *user)
{
    if (detector == NULL) return;
    (void)memset(detector, 0, sizeof(*detector));
    passage_fsm_init(&detector->passage, NULL);
    ab_parser_init(&detector->parser, on_frame, detector);
    detector->tx = tx;
    detector->on_decision = on_decision;
    detector->user = user;
    detector->source_id = DETECTOR_A_DEFAULT_SOURCE_ID;
    detector->boot_id = 1U;
    detector->next_message_id = 1U;
    detector->next_event_id = 1U;
    detector->card_anon_id = 0xA9000001U;
    detector->simulated_auth = HW_UNAUTHORIZED;
}

passage_result_t detector_a_observe(detector_a_t *detector, const passage_observation_t *observation,
                                    uint32_t now_ms)
{
    hw_passage_event_t event;
    passage_result_t result;
    uint8_t payload[AB_MAX_PAYLOAD];
    ab_frame_header_t header;
    size_t payload_len;
    bool sent;
    if (detector == NULL) return PASSAGE_NO_OUTPUT;
    (void)memset(&event, 0, sizeof(event));
    result = passage_fsm_step(&detector->passage, observation, now_ms, &event);
    if (result != PASSAGE_COMPLETED) return result;
    if (detector->pending_active) {
        detector->busy_drops++;
        return result;
    }
    event.event_id = detector->next_event_id++;
    event.source_id = detector->source_id;
    event.boot_id = detector->boot_id;
    event.card_anon_id = detector->card_anon_id;
    event.auth = detector->simulated_auth;
    event.auth_session_id = detector->auth_session_id;
    event.permission_id = detector->auth_permission_id;
    event.auth_counter = detector->auth_counter;
    detector->auth_session_id = 0U;
    detector->auth_permission_id = 0U;
    detector->auth_counter = 0U;
    if (event.auth == HW_AUTHORIZED) detector->simulated_auth = HW_UNAUTHORIZED;
    payload_len = ab_passage_encode(&event, payload, sizeof(payload));
    header = make_header(detector, AB_MSG_PASSAGE_EVENT, AB_FLAG_ACK_REQUIRED);
    detector->pending_length = ab_frame_encode(&header, payload, (uint16_t)payload_len,
                                               detector->pending_frame,
                                               sizeof(detector->pending_frame));
    if (detector->pending_length == 0U) {
        detector->send_failures++;
        return result;
    }
    detector->pending_active = true;
    detector->pending_message_id = header.message_id;
    detector->pending_event_id = event.event_id;
    detector->last_event_id = event.event_id;
    detector->pending_sent_ms = now_ms;
    detector->pending_retries = 0U;
    detector->pending_ack_received = false;
    sent = detector->tx != NULL &&
           detector->tx(detector->pending_frame, detector->pending_length, detector->user);
    if (sent) detector->sent_events++;
    else detector->send_failures++;
    return result;
}

void detector_a_receive(detector_a_t *detector, const uint8_t *data, size_t length)
{
    if (detector != NULL) ab_parser_feed(&detector->parser, data, length);
}

void detector_a_set_auth(detector_a_t *detector, hw_auth_result_t auth)
{
    if (detector != NULL && auth <= HW_REPLAY_SUSPECTED) {
        detector->simulated_auth = auth;
        detector->auth_session_id = 0U;
        detector->auth_permission_id = 0U;
        detector->auth_counter = 0U;
    }
}

bool detector_a_set_auth_result(detector_a_t *detector, const ab_auth_result_t *result)
{
    if (detector == NULL || result == NULL || result->auth > HW_REPLAY_SUSPECTED) return false;
    detector->simulated_auth = result->auth;
    detector->auth_session_id = 0U;
    detector->auth_permission_id = 0U;
    detector->auth_counter = 0U;
    if (result->auth != HW_AUTHORIZED) return true;
    if (result->reason != AB_REASON_NONE || result->session_id == 0U || result->card_id == 0U ||
        result->permission_id == 0U || result->counter == 0U) {
        detector->simulated_auth = HW_UNAUTHORIZED;
        return false;
    }
    detector->card_anon_id = result->card_id;
    detector->auth_session_id = result->session_id;
    detector->auth_permission_id = result->permission_id;
    detector->auth_counter = result->counter;
    return true;
}

void detector_a_set_identity(detector_a_t *detector, uint32_t source_id, uint32_t boot_id)
{
    if (detector == NULL || source_id == 0U || boot_id == 0U) return;
    detector->source_id = source_id;
    detector->boot_id = boot_id;
}

void detector_a_tick(detector_a_t *detector, uint32_t now_ms)
{
    bool sent;
    if (detector == NULL || !detector->pending_active ||
        (int32_t)(now_ms - detector->pending_sent_ms) < (int32_t)DETECTOR_A_ACK_TIMEOUT_MS) {
        return;
    }
    if (detector->pending_retries >= DETECTOR_A_MAX_RETRIES) {
        detector->pending_active = false;
        detector->retry_exhausted++;
        return;
    }
    detector->pending_retries++;
    detector->retry_attempts++;
    detector->pending_sent_ms = now_ms;
    detector->pending_frame[4] |= AB_FLAG_RETRY;
    {
        uint16_t payload_length = (uint16_t)(detector->pending_length - AB_FRAME_OVERHEAD);
        uint16_t crc = ab_crc16_ccitt(&detector->pending_frame[2],
                                      (AB_FRAME_HEADER_SIZE - 2U) + payload_length);
        detector->pending_frame[AB_FRAME_HEADER_SIZE + payload_length] = (uint8_t)crc;
        detector->pending_frame[AB_FRAME_HEADER_SIZE + payload_length + 1U] = (uint8_t)(crc >> 8);
    }
    sent = detector->tx != NULL &&
           detector->tx(detector->pending_frame, detector->pending_length, detector->user);
    if (!sent) detector->send_failures++;
}
