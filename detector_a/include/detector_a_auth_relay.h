#ifndef SLE_DETECTOR_A_AUTH_RELAY_H
#define SLE_DETECTOR_A_AUTH_RELAY_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "ab_messages.h"
#include "ab_protocol.h"

#define DETECTOR_A_AUTH_RELAY_SESSIONS 4U
#define DETECTOR_A_AUTH_RELAY_TIMEOUT_MS 7000U
#define DETECTOR_A_AUTH_RELAY_RETRY_MS 500U
#define DETECTOR_A_AUTH_RELAY_MAX_RETRIES 3U

typedef bool (*detector_a_auth_tx_fn)(const uint8_t *data, size_t length, void *user);
typedef void (*detector_a_auth_result_fn)(const ab_auth_result_t *result, void *user);

typedef struct {
    bool valid;
    bool response_seen;
    bool result_seen;
    uint32_t session_id;
    uint32_t expires_ms;
    uint32_t challenge_last_sent_ms;
    uint32_t response_last_sent_ms;
    uint8_t challenge_retries;
    uint8_t response_retries;
    uint8_t challenge[64];
    uint8_t response[48];
    ab_auth_result_t result;
} detector_a_auth_relay_session_t;

typedef struct {
    ab_stream_parser_t b_parser;
    ab_stream_parser_t card_parser;
    detector_a_auth_tx_fn tx_to_b;
    detector_a_auth_tx_fn tx_to_card;
    detector_a_auth_result_fn on_result;
    void *user;
    uint32_t source_id;
    uint32_t boot_id;
    uint32_t next_message_id;
    uint32_t receive_now_ms;
    detector_a_auth_relay_session_t sessions[DETECTOR_A_AUTH_RELAY_SESSIONS];
    uint32_t challenges_forwarded;
    uint32_t responses_forwarded;
    uint32_t results_received;
    uint32_t duplicate_messages;
    uint32_t malformed_messages;
    uint32_t replay_rejections;
    uint32_t expired_sessions;
    uint32_t b_send_failures;
    uint32_t card_send_failures;
    uint32_t challenge_retry_attempts;
    uint32_t response_retry_attempts;
} detector_a_auth_relay_t;

void detector_a_auth_relay_init(detector_a_auth_relay_t *relay,
                                detector_a_auth_tx_fn tx_to_b,
                                detector_a_auth_tx_fn tx_to_card,
                                detector_a_auth_result_fn on_result, void *user);
void detector_a_auth_relay_set_identity(detector_a_auth_relay_t *relay,
                                        uint32_t source_id, uint32_t boot_id);
void detector_a_auth_relay_receive_b(detector_a_auth_relay_t *relay,
                                     const uint8_t *data, size_t length,
                                     uint32_t now_ms);
void detector_a_auth_relay_receive_card(detector_a_auth_relay_t *relay,
                                        const uint8_t *data, size_t length,
                                        uint32_t now_ms);
void detector_a_auth_relay_tick(detector_a_auth_relay_t *relay, uint32_t now_ms);

#endif
