#include "detector_a_auth_relay.h"

#include <string.h>

#define AUTH_CHALLENGE_SIZE 64U
#define AUTH_RESPONSE_SIZE 48U

static uint32_t read_u32(const uint8_t *data)
{
    return (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
           ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
}

static bool time_reached(uint32_t now_ms, uint32_t deadline_ms)
{
    return (int32_t)(now_ms - deadline_ms) >= 0;
}

static bool result_equal(const ab_auth_result_t *left, const ab_auth_result_t *right)
{
    return left->session_id == right->session_id && left->card_id == right->card_id &&
           left->permission_id == right->permission_id && left->auth == right->auth &&
           left->reason == right->reason && left->counter == right->counter;
}

static detector_a_auth_relay_session_t *find_session(detector_a_auth_relay_t *relay,
                                                       uint32_t session_id)
{
    uint8_t i;
    for (i = 0U; i < DETECTOR_A_AUTH_RELAY_SESSIONS; ++i)
        if (relay->sessions[i].valid && relay->sessions[i].session_id == session_id)
            return &relay->sessions[i];
    return NULL;
}

static detector_a_auth_relay_session_t *allocate_session(detector_a_auth_relay_t *relay)
{
    uint8_t i;
    for (i = 0U; i < DETECTOR_A_AUTH_RELAY_SESSIONS; ++i) {
        detector_a_auth_relay_session_t *session = &relay->sessions[i];
        if (!session->valid || time_reached(relay->receive_now_ms, session->expires_ms)) {
            if (session->valid && !session->result_seen) relay->expired_sessions++;
            (void)memset(session, 0, sizeof(*session));
            return session;
        }
    }
    for (i = 0U; i < DETECTOR_A_AUTH_RELAY_SESSIONS; ++i) {
        detector_a_auth_relay_session_t *session = &relay->sessions[i];
        if (session->result_seen) {
            (void)memset(session, 0, sizeof(*session));
            return session;
        }
    }
    return NULL;
}

static bool forward(detector_a_auth_relay_t *relay, detector_a_auth_tx_fn tx,
                    uint8_t type, uint8_t flags, const uint8_t *payload,
                    uint16_t payload_length)
{
    uint8_t frame[AB_MAX_FRAME];
    ab_frame_header_t header = { 0 };
    size_t frame_length;
    header.type = type;
    header.flags = flags;
    header.source_role = AB_ROLE_DETECTOR_A;
    header.source_id = relay->source_id;
    header.boot_id = relay->boot_id;
    header.message_id = relay->next_message_id++;
    frame_length = ab_frame_encode(&header, payload, payload_length, frame, sizeof(frame));
    return tx != NULL && frame_length != 0U && tx(frame, frame_length, relay->user);
}

static void on_b_frame(const ab_frame_t *frame, void *user)
{
    detector_a_auth_relay_t *relay = (detector_a_auth_relay_t *)user;
    detector_a_auth_relay_session_t *session;
    ab_auth_result_t result;
    uint32_t session_id;
    if (frame->header.source_role != AB_ROLE_DETECTOR_B) return;
    if (frame->header.type == AB_MSG_AUTH_CHALLENGE) {
        if (frame->payload_length != AUTH_CHALLENGE_SIZE ||
            (session_id = read_u32(frame->payload)) == 0U) {
            relay->malformed_messages++;
            return;
        }
        session = find_session(relay, session_id);
        if (session != NULL) {
            if (memcmp(session->challenge, frame->payload, AUTH_CHALLENGE_SIZE) != 0) {
                relay->replay_rejections++;
                return;
            }
            relay->duplicate_messages++;
        } else {
            session = allocate_session(relay);
            if (session == NULL) {
                relay->malformed_messages++;
                return;
            }
            session->valid = true;
            session->session_id = session_id;
            session->expires_ms = relay->receive_now_ms + DETECTOR_A_AUTH_RELAY_TIMEOUT_MS;
            (void)memcpy(session->challenge, frame->payload, AUTH_CHALLENGE_SIZE);
        }
        if (forward(relay, relay->tx_to_card, AB_MSG_AUTH_CHALLENGE, 0U,
                    frame->payload, frame->payload_length))
            relay->challenges_forwarded++;
        else
            relay->card_send_failures++;
        session->challenge_last_sent_ms = relay->receive_now_ms;
        return;
    }
    if (frame->header.type != AB_MSG_AUTH_RESULT) return;
    if (!ab_auth_result_decode(frame->payload, frame->payload_length, &result)) {
        relay->malformed_messages++;
        return;
    }
    session = find_session(relay, result.session_id);
    if (session == NULL || time_reached(relay->receive_now_ms, session->expires_ms)) {
        relay->replay_rejections++;
        return;
    }
    if (session->result_seen) {
        if (result_equal(&session->result, &result))
            relay->duplicate_messages++;
        else
            relay->replay_rejections++;
        return;
    }
    session->result_seen = true;
    session->result = result;
    relay->results_received++;
    if (relay->on_result != NULL) relay->on_result(&result, relay->user);
}

static void on_card_frame(const ab_frame_t *frame, void *user)
{
    detector_a_auth_relay_t *relay = (detector_a_auth_relay_t *)user;
    detector_a_auth_relay_session_t *session;
    uint32_t session_id;
    if (frame->header.source_role != AB_ROLE_CARD || frame->header.type != AB_MSG_AUTH_RESPONSE)
        return;
    if (frame->payload_length != AUTH_RESPONSE_SIZE ||
        (session_id = read_u32(frame->payload)) == 0U) {
        relay->malformed_messages++;
        return;
    }
    session = find_session(relay, session_id);
    if (session == NULL || session->result_seen ||
        time_reached(relay->receive_now_ms, session->expires_ms)) {
        relay->replay_rejections++;
        return;
    }
    if (session->response_seen) {
        if (memcmp(session->response, frame->payload, AUTH_RESPONSE_SIZE) != 0) {
            relay->replay_rejections++;
            return;
        }
        relay->duplicate_messages++;
    } else {
        session->response_seen = true;
        (void)memcpy(session->response, frame->payload, AUTH_RESPONSE_SIZE);
    }
    if (forward(relay, relay->tx_to_b, AB_MSG_AUTH_RESPONSE, 0U,
                frame->payload, frame->payload_length))
        relay->responses_forwarded++;
    else
        relay->b_send_failures++;
    session->response_last_sent_ms = relay->receive_now_ms;
}

void detector_a_auth_relay_init(detector_a_auth_relay_t *relay,
                                detector_a_auth_tx_fn tx_to_b,
                                detector_a_auth_tx_fn tx_to_card,
                                detector_a_auth_result_fn on_result, void *user)
{
    if (relay == NULL) return;
    (void)memset(relay, 0, sizeof(*relay));
    relay->tx_to_b = tx_to_b;
    relay->tx_to_card = tx_to_card;
    relay->on_result = on_result;
    relay->user = user;
    relay->source_id = 0xA0000001U;
    relay->boot_id = 1U;
    relay->next_message_id = 1U;
    ab_parser_init(&relay->b_parser, on_b_frame, relay);
    ab_parser_init(&relay->card_parser, on_card_frame, relay);
}

void detector_a_auth_relay_set_identity(detector_a_auth_relay_t *relay,
                                        uint32_t source_id, uint32_t boot_id)
{
    if (relay == NULL || source_id == 0U || boot_id == 0U) return;
    relay->source_id = source_id;
    relay->boot_id = boot_id;
}

void detector_a_auth_relay_receive_b(detector_a_auth_relay_t *relay,
                                     const uint8_t *data, size_t length,
                                     uint32_t now_ms)
{
    if (relay == NULL) return;
    relay->receive_now_ms = now_ms;
    ab_parser_feed(&relay->b_parser, data, length);
}

void detector_a_auth_relay_receive_card(detector_a_auth_relay_t *relay,
                                        const uint8_t *data, size_t length,
                                        uint32_t now_ms)
{
    if (relay == NULL) return;
    relay->receive_now_ms = now_ms;
    ab_parser_feed(&relay->card_parser, data, length);
}

void detector_a_auth_relay_tick(detector_a_auth_relay_t *relay, uint32_t now_ms)
{
    uint8_t i;
    if (relay == NULL) return;
    for (i = 0U; i < DETECTOR_A_AUTH_RELAY_SESSIONS; ++i) {
        detector_a_auth_relay_session_t *session = &relay->sessions[i];
        if (session->valid && !session->result_seen && time_reached(now_ms, session->expires_ms)) {
            session->valid = false;
            relay->expired_sessions++;
            continue;
        }
        if (!session->valid || session->result_seen) continue;
        if (!session->response_seen &&
            session->challenge_retries < DETECTOR_A_AUTH_RELAY_MAX_RETRIES &&
            time_reached(now_ms,
                         session->challenge_last_sent_ms + DETECTOR_A_AUTH_RELAY_RETRY_MS)) {
            session->challenge_retries++;
            relay->challenge_retry_attempts++;
            session->challenge_last_sent_ms = now_ms;
            if (forward(relay, relay->tx_to_card, AB_MSG_AUTH_CHALLENGE, AB_FLAG_RETRY,
                        session->challenge, AUTH_CHALLENGE_SIZE))
                relay->challenges_forwarded++;
            else
                relay->card_send_failures++;
        } else if (session->response_seen &&
                   session->response_retries < DETECTOR_A_AUTH_RELAY_MAX_RETRIES &&
                   time_reached(now_ms,
                                session->response_last_sent_ms +
                                DETECTOR_A_AUTH_RELAY_RETRY_MS)) {
            session->response_retries++;
            relay->response_retry_attempts++;
            session->response_last_sent_ms = now_ms;
            if (forward(relay, relay->tx_to_b, AB_MSG_AUTH_RESPONSE, AB_FLAG_RETRY,
                        session->response, AUTH_RESPONSE_SIZE))
                relay->responses_forwarded++;
            else
                relay->b_send_failures++;
        }
    }
}
