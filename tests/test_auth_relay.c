#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "detector_a_auth_relay.h"

typedef struct {
    uint8_t to_b[AB_MAX_FRAME];
    size_t to_b_length;
    uint8_t to_card[AB_MAX_FRAME];
    size_t to_card_length;
    ab_auth_result_t result;
    uint32_t result_calls;
    uint32_t to_b_calls;
    uint32_t to_card_calls;
} relay_log_t;

typedef struct {
    ab_frame_t frame;
    bool received;
} decoded_frame_t;

static bool tx_b(const uint8_t *data, size_t length, void *user)
{
    relay_log_t *log = (relay_log_t *)user;
    (void)memcpy(log->to_b, data, length);
    log->to_b_length = length;
    log->to_b_calls++;
    return true;
}

static bool tx_card(const uint8_t *data, size_t length, void *user)
{
    relay_log_t *log = (relay_log_t *)user;
    (void)memcpy(log->to_card, data, length);
    log->to_card_length = length;
    log->to_card_calls++;
    return true;
}

static void auth_result(const ab_auth_result_t *result, void *user)
{
    relay_log_t *log = (relay_log_t *)user;
    log->result = *result;
    log->result_calls++;
}

static void decoded(const ab_frame_t *frame, void *user)
{
    decoded_frame_t *output = (decoded_frame_t *)user;
    output->frame = *frame;
    output->received = true;
}

static size_t make_frame(uint8_t role, uint8_t type, const uint8_t *payload,
                         uint16_t payload_length, uint8_t *output)
{
    ab_frame_header_t header = { 0 };
    header.type = type;
    header.source_role = role;
    header.source_id = role == AB_ROLE_CARD ? 0xC0000001U : 0xB0000001U;
    header.boot_id = 1U;
    header.message_id = 1U;
    return ab_frame_encode(&header, payload, payload_length, output, AB_MAX_FRAME);
}

static ab_frame_t decode_one(const uint8_t *data, size_t length)
{
    ab_stream_parser_t parser;
    decoded_frame_t output = { 0 };
    ab_parser_init(&parser, decoded, &output);
    ab_parser_feed(&parser, data, length);
    assert(output.received);
    return output.frame;
}

static void write_u32(uint8_t *data, uint32_t value)
{
    data[0] = (uint8_t)value;
    data[1] = (uint8_t)(value >> 8);
    data[2] = (uint8_t)(value >> 16);
    data[3] = (uint8_t)(value >> 24);
}

static void test_relay_routing_and_idempotency(void)
{
    detector_a_auth_relay_t relay;
    relay_log_t log = { 0 };
    uint8_t challenge[64] = { 0 };
    uint8_t response[48] = { 0 };
    uint8_t result_payload[AB_AUTH_RESULT_PAYLOAD_SIZE];
    uint8_t input[AB_MAX_FRAME];
    size_t input_length;
    ab_frame_t forwarded;
    ab_auth_result_t result = { 0 };
    uint32_t responses_before;

    write_u32(&challenge[0], 0x12345678U);
    challenge[4] = 1U;
    write_u32(&response[0], 0x12345678U);
    write_u32(&response[4], 7U);
    write_u32(&response[12], 0xC0000001U);
    write_u32(&response[16], 1U);
    detector_a_auth_relay_init(&relay, tx_b, tx_card, auth_result, &log);
    detector_a_auth_relay_set_identity(&relay, 0xA0000001U, 0xAABBCCDDU);

    input_length = make_frame(AB_ROLE_DETECTOR_B, AB_MSG_AUTH_CHALLENGE,
                              challenge, sizeof(challenge), input);
    detector_a_auth_relay_receive_b(&relay, input, input_length, 100U);
    assert(relay.challenges_forwarded == 1U && log.to_card_length != 0U);
    forwarded = decode_one(log.to_card, log.to_card_length);
    assert(forwarded.header.source_role == AB_ROLE_DETECTOR_A &&
           forwarded.header.source_id == 0xA0000001U &&
           forwarded.header.boot_id == 0xAABBCCDDU &&
           forwarded.header.type == AB_MSG_AUTH_CHALLENGE &&
           memcmp(forwarded.payload, challenge, sizeof(challenge)) == 0);

    detector_a_auth_relay_receive_b(&relay, input, input_length, 101U);
    assert(relay.duplicate_messages == 1U && relay.challenges_forwarded == 2U);
    challenge[10] ^= 1U;
    input_length = make_frame(AB_ROLE_DETECTOR_B, AB_MSG_AUTH_CHALLENGE,
                              challenge, sizeof(challenge), input);
    detector_a_auth_relay_receive_b(&relay, input, input_length, 102U);
    assert(relay.replay_rejections == 1U && relay.challenges_forwarded == 2U);

    input_length = make_frame(AB_ROLE_CARD, AB_MSG_AUTH_RESPONSE,
                              response, sizeof(response), input);
    detector_a_auth_relay_receive_card(&relay, input, input_length, 200U);
    assert(relay.responses_forwarded == 1U && log.to_b_length != 0U);
    forwarded = decode_one(log.to_b, log.to_b_length);
    assert(forwarded.header.source_role == AB_ROLE_DETECTOR_A &&
           forwarded.header.type == AB_MSG_AUTH_RESPONSE &&
           memcmp(forwarded.payload, response, sizeof(response)) == 0);
    detector_a_auth_relay_receive_card(&relay, input, input_length, 201U);
    assert(relay.responses_forwarded == 2U && relay.duplicate_messages == 2U);
    responses_before = relay.responses_forwarded;
    response[20] ^= 1U;
    input_length = make_frame(AB_ROLE_CARD, AB_MSG_AUTH_RESPONSE,
                              response, sizeof(response), input);
    detector_a_auth_relay_receive_card(&relay, input, input_length, 202U);
    assert(relay.responses_forwarded == responses_before && relay.replay_rejections == 2U);

    result.session_id = 0x12345678U;
    result.card_id = 0xC0000001U;
    result.permission_id = 7U;
    result.auth = HW_AUTHORIZED;
    result.reason = AB_REASON_NONE;
    result.counter = 1U;
    assert(ab_auth_result_encode(&result, result_payload, sizeof(result_payload)) ==
           AB_AUTH_RESULT_PAYLOAD_SIZE);
    input_length = make_frame(AB_ROLE_DETECTOR_B, AB_MSG_AUTH_RESULT,
                              result_payload, sizeof(result_payload), input);
    detector_a_auth_relay_receive_b(&relay, input, input_length, 300U);
    assert(log.result_calls == 1U && relay.results_received == 1U &&
           log.result.auth == HW_AUTHORIZED);
    detector_a_auth_relay_receive_b(&relay, input, input_length, 301U);
    assert(log.result_calls == 1U && relay.duplicate_messages == 3U);

    (void)memset(challenge, 0, sizeof(challenge));
    write_u32(&challenge[0], 0x12345679U);
    challenge[4] = 2U;
    input_length = make_frame(AB_ROLE_DETECTOR_B, AB_MSG_AUTH_CHALLENGE,
                              challenge, sizeof(challenge), input);
    detector_a_auth_relay_receive_b(&relay, input, input_length, 302U);
    assert(relay.sessions[0].session_id == 0x12345678U &&
           relay.sessions[1].session_id == 0x12345679U);
}

static void test_relay_timeout(void)
{
    detector_a_auth_relay_t relay;
    relay_log_t log = { 0 };
    uint8_t challenge[64] = { 0 };
    uint8_t response[48] = { 0 };
    uint8_t input[AB_MAX_FRAME];
    size_t input_length;
    write_u32(&challenge[0], 9U);
    challenge[4] = 1U;
    write_u32(&response[0], 9U);
    detector_a_auth_relay_init(&relay, tx_b, tx_card, auth_result, &log);
    input_length = make_frame(AB_ROLE_DETECTOR_B, AB_MSG_AUTH_CHALLENGE,
                              challenge, sizeof(challenge), input);
    detector_a_auth_relay_receive_b(&relay, input, input_length, 10U);
    detector_a_auth_relay_tick(&relay, 7010U);
    assert(relay.expired_sessions == 1U);
    input_length = make_frame(AB_ROLE_CARD, AB_MSG_AUTH_RESPONSE,
                              response, sizeof(response), input);
    detector_a_auth_relay_receive_card(&relay, input, input_length, 7011U);
    assert(relay.responses_forwarded == 0U && relay.replay_rejections == 1U);
}

static void test_relay_retries_until_result(void)
{
    detector_a_auth_relay_t relay;
    relay_log_t log = { 0 };
    uint8_t challenge[64] = { 0 };
    uint8_t response[48] = { 0 };
    uint8_t result_payload[AB_AUTH_RESULT_PAYLOAD_SIZE];
    uint8_t input[AB_MAX_FRAME];
    size_t input_length;
    ab_auth_result_t result = { 0 };

    write_u32(&challenge[0], 10U);
    challenge[4] = 1U;
    write_u32(&response[0], 10U);
    write_u32(&response[4], 7U);
    write_u32(&response[12], 0xC0000001U);
    write_u32(&response[16], 1U);
    detector_a_auth_relay_init(&relay, tx_b, tx_card, auth_result, &log);

    input_length = make_frame(AB_ROLE_DETECTOR_B, AB_MSG_AUTH_CHALLENGE,
                              challenge, sizeof(challenge), input);
    detector_a_auth_relay_receive_b(&relay, input, input_length, 100U);
    assert(log.to_card_calls == 1U);
    detector_a_auth_relay_tick(&relay, 600U);
    assert(log.to_card_calls == 2U && relay.challenge_retry_attempts == 1U);

    input_length = make_frame(AB_ROLE_CARD, AB_MSG_AUTH_RESPONSE,
                              response, sizeof(response), input);
    detector_a_auth_relay_receive_card(&relay, input, input_length, 700U);
    assert(log.to_b_calls == 1U);
    detector_a_auth_relay_tick(&relay, 1200U);
    assert(log.to_b_calls == 2U && relay.response_retry_attempts == 1U);

    result.session_id = 10U;
    result.card_id = 0xC0000001U;
    result.permission_id = 7U;
    result.auth = HW_AUTHORIZED;
    result.reason = AB_REASON_NONE;
    result.counter = 1U;
    assert(ab_auth_result_encode(&result, result_payload, sizeof(result_payload)) ==
           AB_AUTH_RESULT_PAYLOAD_SIZE);
    input_length = make_frame(AB_ROLE_DETECTOR_B, AB_MSG_AUTH_RESULT,
                              result_payload, sizeof(result_payload), input);
    detector_a_auth_relay_receive_b(&relay, input, input_length, 1300U);
    detector_a_auth_relay_tick(&relay, 1800U);
    assert(log.to_b_calls == 2U && log.to_card_calls == 2U);
    assert(log.result_calls == 1U);
}

int main(void)
{
    test_relay_routing_and_idempotency();
    test_relay_timeout();
    test_relay_retries_until_result();
    puts("All Detector A authentication relay tests passed.");
    return 0;
}
