#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "card_auth.h"
#include "card_crypto.h"
#include "credential_store.h"
#include "detector_b_auth.h"

typedef struct {
    uint8_t slots[CARD_STORE_SLOT_COUNT][CARD_STORE_SLOT_SIZE];
    bool present[CARD_STORE_SLOT_COUNT];
} memory_store_t;

typedef struct {
    uint8_t response[CARD_AUTH_RESPONSE_SIZE];
    uint16_t length;
} response_capture_t;

typedef struct {
    uint8_t next;
} random_state_t;

static bool memory_read(uint8_t slot, uint8_t *data, size_t length, void *user)
{
    memory_store_t *memory = (memory_store_t *)user;
    if (slot >= CARD_STORE_SLOT_COUNT || length != CARD_STORE_SLOT_SIZE ||
        !memory->present[slot]) return false;
    (void)memcpy(data, memory->slots[slot], length);
    return true;
}

static bool memory_write(uint8_t slot, const uint8_t *data, size_t length, void *user)
{
    memory_store_t *memory = (memory_store_t *)user;
    if (slot >= CARD_STORE_SLOT_COUNT || length != CARD_STORE_SLOT_SIZE) return false;
    (void)memcpy(memory->slots[slot], data, length);
    memory->present[slot] = true;
    return true;
}

static bool capture_response(uint8_t type, uint8_t flags, const uint8_t *payload,
                             uint16_t length, void *user)
{
    response_capture_t *capture = (response_capture_t *)user;
    (void)flags;
    if (type != AB_MSG_AUTH_RESPONSE || length != CARD_AUTH_RESPONSE_SIZE) return false;
    (void)memcpy(capture->response, payload, length);
    capture->length = length;
    return true;
}

static bool deterministic_random(uint8_t *output, size_t length, void *user)
{
    random_state_t *state = (random_state_t *)user;
    size_t i;
    for (i = 0U; i < length; ++i) output[i] = ++state->next;
    return true;
}

static card_credential_t make_card_credential(void)
{
    card_credential_t credential = { 0 };
    uint8_t i;
    credential.permission_id = 7U;
    credential.organization_id = 100U;
    credential.scope_type = CARD_SCOPE_CHECKPOINT;
    credential.scope_id = 9U;
    credential.valid_from = 900U;
    credential.valid_to = 1100U;
    credential.usage_limit = 4U;
    credential.credential_version = 3U;
    credential.key_version = 2U;
    credential.state = CARD_CREDENTIAL_ACTIVE;
    for (i = 0U; i < CARD_KEY_SIZE; ++i) credential.key[i] = (uint8_t)(0x40U + i);
    return credential;
}

static detector_b_auth_credential_t make_b_credential(const card_credential_t *card)
{
    detector_b_auth_credential_t credential = { 0 };
    credential.permission_id = card->permission_id;
    credential.organization_id = card->organization_id;
    credential.expected_card_id = 0xC0000001U;
    credential.valid_from = card->valid_from;
    credential.valid_to = card->valid_to;
    credential.usage_limit = card->usage_limit;
    credential.highest_counter = card->usage_count;
    credential.credential_version = card->credential_version;
    credential.key_version = card->key_version;
    credential.state = DETECTOR_B_CREDENTIAL_ACTIVE;
    (void)memcpy(credential.key, card->key, sizeof(credential.key));
    return credential;
}

static void test_b_card_interoperability(void)
{
    memory_store_t memory = { 0 };
    card_store_backend_t backend = { memory_read, memory_write, &memory };
    card_store_t store;
    card_authenticator_t card_auth;
    card_credential_t card_credential = make_card_credential();
    detector_b_auth_credential_t b_credential = make_b_credential(&card_credential);
    detector_b_auth_t b_auth;
    detector_b_auth_request_t request = { 100U, 7U, 1000U, 0x12345678U };
    response_capture_t capture = { 0 };
    random_state_t random = { 0 };
    uint8_t challenge[DETECTOR_B_AUTH_CHALLENGE_SIZE];
    uint8_t original_response[DETECTOR_B_AUTH_RESPONSE_SIZE];
    uint8_t result_payload[AB_AUTH_RESULT_PAYLOAD_SIZE];
    ab_auth_result_t result;
    ab_auth_result_t decoded;
    ab_reason_t reason;

    assert(card_store_init(&store, &backend) == CARD_STORE_OK);
    assert(card_store_upsert(&store, &card_credential) == CARD_STORE_OK);
    card_auth_init(&card_auth, &store, 0xC0000001U, 0xB001B001U,
                   capture_response, &capture);
    detector_b_auth_init(&b_auth, 0xB0000001U, deterministic_random,
                         card_hmac_sha256, &random);
    assert(detector_b_auth_upsert(&b_auth, &b_credential));

    assert(detector_b_auth_start(&b_auth, &request, 100U, challenge, &reason));
    assert(reason == AB_REASON_NONE);
    assert(card_auth_handle_challenge(&card_auth, challenge, sizeof(challenge)) == CARD_AUTH_OK);
    assert(detector_b_auth_verify(&b_auth, capture.response, capture.length, 200U, &result));
    assert(result.auth == HW_AUTHORIZED && result.reason == AB_REASON_NONE);
    assert(result.card_id == 0xC0000001U && result.permission_id == 7U && result.counter == 1U);
    assert(b_auth.sessions[0].expires_ms == 200U + DETECTOR_B_AUTH_GRANT_TIMEOUT_MS);
    assert(ab_auth_result_encode(&result, result_payload, sizeof(result_payload)) ==
           AB_AUTH_RESULT_PAYLOAD_SIZE);
    assert(ab_auth_result_decode(result_payload, sizeof(result_payload), &decoded));
    assert(result.session_id == decoded.session_id && result.card_id == decoded.card_id &&
           result.permission_id == decoded.permission_id && result.auth == decoded.auth &&
           result.reason == decoded.reason && result.counter == decoded.counter);
    /* The grant remains usable after the original challenge deadline (5100 ms). */
    assert(detector_b_auth_consume(&b_auth, result.session_id, result.card_id,
                                   result.permission_id, result.counter, 6000U));
    assert(!detector_b_auth_consume(&b_auth, result.session_id, result.card_id,
                                    result.permission_id, result.counter, 201U));
    assert(b_auth.consumed_grants == 1U);

    (void)memset(&decoded, 0xA5, sizeof(decoded));
    assert(!detector_b_auth_verify(&b_auth, capture.response, 1U, 201U, &decoded));
    assert(decoded.session_id == 0U && decoded.auth == HW_UNAUTHORIZED &&
           decoded.reason == AB_REASON_BAD_MESSAGE);

    assert(detector_b_auth_verify(&b_auth, capture.response, capture.length, 202U, &decoded));
    assert(b_auth.duplicate_responses == 1U && b_auth.successful_responses == 1U);
    capture.response[47] ^= 1U;
    assert(!detector_b_auth_verify(&b_auth, capture.response, capture.length, 202U, &decoded));
    assert(decoded.auth == HW_REPLAY_SUSPECTED);

    assert(detector_b_auth_start(&b_auth, &request, 300U, challenge, &reason));
    assert(card_auth_handle_challenge(&card_auth, challenge, sizeof(challenge)) == CARD_AUTH_OK);
    (void)memcpy(original_response, capture.response, sizeof(original_response));
    capture.response[40] ^= 1U;
    assert(!detector_b_auth_verify(&b_auth, capture.response, capture.length, 400U, &decoded));
    assert(decoded.auth == HW_KEY_FAILED && decoded.reason == AB_REASON_KEY_FAILED);
    assert(detector_b_auth_verify(&b_auth, original_response, sizeof(original_response),
                                  401U, &decoded));
    assert(decoded.counter == 2U);
    assert(!detector_b_auth_consume(&b_auth, decoded.session_id, decoded.card_id,
                                    decoded.permission_id, decoded.counter + 1U, 401U));
    assert(detector_b_auth_consume(&b_auth, decoded.session_id, decoded.card_id,
                                   decoded.permission_id, decoded.counter, 401U));
    assert(detector_b_auth_verify(&b_auth, b_auth.sessions[0].response,
                                  DETECTOR_B_AUTH_RESPONSE_SIZE, 402U, &decoded));
    assert(decoded.counter == 1U && b_auth.duplicate_responses == 2U);

    b_credential.highest_counter = 0U;
    assert(detector_b_auth_upsert(&b_auth, &b_credential));
    assert(b_auth.credentials[0].highest_counter == 2U);
    b_credential.credential_version = 2U;
    assert(!detector_b_auth_upsert(&b_auth, &b_credential));
    b_credential.credential_version = 3U;
    b_credential.highest_counter = 2U;

    assert(detector_b_auth_start(&b_auth, &request, 500U, challenge, &reason));
    assert(!detector_b_auth_upsert(&b_auth, &b_credential));
    assert(card_auth_handle_challenge(&card_auth, challenge, sizeof(challenge)) == CARD_AUTH_OK);
    assert(!detector_b_auth_verify(&b_auth, capture.response, capture.length,
                                   5500U, &decoded));
    assert(decoded.reason == AB_REASON_STALE_REQUEST);
}

static void test_credential_denial_reasons(void)
{
    detector_b_auth_t auth;
    detector_b_auth_credential_t credential = { 0 };
    detector_b_auth_request_t request = { 100U, 9U, 1000U, 1U };
    random_state_t random = { 0 };
    uint8_t challenge[DETECTOR_B_AUTH_CHALLENGE_SIZE];
    ab_reason_t reason;
    credential.permission_id = 9U;
    credential.organization_id = 100U;
    credential.valid_from = 900U;
    credential.valid_to = 1100U;
    credential.usage_limit = 1U;
    credential.credential_version = 1U;
    credential.key_version = 1U;
    credential.state = DETECTOR_B_CREDENTIAL_FROZEN;
    (void)memset(credential.key, 0x55, sizeof(credential.key));
    detector_b_auth_init(&auth, 0xB0000001U, deterministic_random,
                         card_hmac_sha256, &random);
    assert(detector_b_auth_upsert(&auth, &credential));
    assert(!detector_b_auth_start(&auth, &request, 1U, challenge, &reason));
    assert(reason == AB_REASON_FROZEN);
    credential.state = DETECTOR_B_CREDENTIAL_ACTIVE;
    credential.highest_counter = 1U;
    assert(detector_b_auth_upsert(&auth, &credential));
    assert(!detector_b_auth_start(&auth, &request, 1U, challenge, &reason));
    assert(reason == AB_REASON_USAGE_EXHAUSTED);
}

int main(void)
{
    test_b_card_interoperability();
    test_credential_denial_reasons();
    puts("All B authority and Card authentication interoperability tests passed.");
    return 0;
}
