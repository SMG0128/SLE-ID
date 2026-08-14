#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "card_auth.h"
#include "card_crypto.h"

typedef struct {
    uint8_t slots[CARD_STORE_SLOT_COUNT][CARD_STORE_SLOT_SIZE];
    bool present[CARD_STORE_SLOT_COUNT];
    bool fail_next_write;
} memory_store_t;

typedef struct {
    uint8_t type;
    uint16_t length;
    uint8_t payload[AB_MAX_PAYLOAD];
    uint32_t sends;
    bool fail_next;
} response_log_t;

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
    if (memory->fail_next_write) {
        memory->fail_next_write = false;
        return false;
    }
    (void)memcpy(memory->slots[slot], data, length);
    memory->present[slot] = true;
    return true;
}

static bool capture(uint8_t type, uint8_t flags, const uint8_t *payload,
                    uint16_t length, void *user)
{
    response_log_t *log = (response_log_t *)user;
    (void)flags;
    if (log->fail_next) {
        log->fail_next = false;
        return false;
    }
    log->type = type;
    log->length = length;
    (void)memcpy(log->payload, payload, length);
    log->sends++;
    return true;
}

static void write_u32(uint8_t *data, uint32_t value)
{
    data[0] = (uint8_t)value;
    data[1] = (uint8_t)(value >> 8);
    data[2] = (uint8_t)(value >> 16);
    data[3] = (uint8_t)(value >> 24);
}

static uint32_t read_u32(const uint8_t *data)
{
    return (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
           ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
}

static void make_challenge(const card_credential_t *credential, uint32_t session_id,
                           uint32_t minimum_counter, uint32_t unix_time,
                           uint8_t challenge[CARD_AUTH_CHALLENGE_SIZE])
{
    static const uint8_t domain[] = "SLE-AUTH-CHAL-V1";
    uint8_t material[sizeof(domain) - 1U + 1U + CARD_AUTH_CHALLENGE_BODY_SIZE];
    uint8_t digest[CARD_SHA256_SIZE];
    uint8_t i;
    (void)memset(challenge, 0, CARD_AUTH_CHALLENGE_SIZE);
    write_u32(&challenge[0], session_id);
    for (i = 0U; i < CARD_AUTH_NONCE_SIZE; ++i) challenge[4U + i] = (uint8_t)(i + 1U);
    write_u32(&challenge[16], 0xA0000001U);
    write_u32(&challenge[20], credential->organization_id);
    write_u32(&challenge[24], credential->permission_id);
    write_u32(&challenge[28], credential->credential_version);
    write_u32(&challenge[32], credential->key_version);
    write_u32(&challenge[36], minimum_counter);
    write_u32(&challenge[40], unix_time);
    write_u32(&challenge[44], 0x12345678U);
    (void)memcpy(material, domain, sizeof(domain) - 1U);
    material[sizeof(domain) - 1U] = AB_PROTOCOL_VERSION;
    (void)memcpy(&material[sizeof(domain)], challenge, CARD_AUTH_CHALLENGE_BODY_SIZE);
    card_hmac_sha256(credential->key, CARD_KEY_SIZE, material, sizeof(material), digest);
    (void)memcpy(&challenge[CARD_AUTH_CHALLENGE_BODY_SIZE], digest, CARD_AUTH_TAG_SIZE);
}

static void test_rfc4231_hmac(void)
{
    static const uint8_t expected[CARD_SHA256_SIZE] = {
        0xb0, 0x34, 0x4c, 0x61, 0xd8, 0xdb, 0x38, 0x53,
        0x5c, 0xa8, 0xaf, 0xce, 0xaf, 0x0b, 0xf1, 0x2b,
        0x88, 0x1d, 0xc2, 0x00, 0xc9, 0x83, 0x3d, 0xa7,
        0x26, 0xe9, 0x37, 0x6c, 0x2e, 0x32, 0xcf, 0xf7
    };
    uint8_t key[20];
    uint8_t output[CARD_SHA256_SIZE];
    (void)memset(key, 0x0b, sizeof(key));
    card_hmac_sha256(key, sizeof(key), (const uint8_t *)"Hi There", 8U, output);
    assert(memcmp(output, expected, sizeof(expected)) == 0);
    assert(card_constant_time_equal(output, expected, sizeof(expected)));
    output[0] ^= 1U;
    assert(!card_constant_time_equal(output, expected, sizeof(expected)));
}

static void test_authentication_and_replay(void)
{
    memory_store_t memory = { 0 };
    card_store_backend_t backend = { memory_read, memory_write, &memory };
    card_store_t store;
    card_store_t rebooted;
    card_credential_t credential = { 0 };
    card_credential_t persisted = { 0 };
    card_authenticator_t auth;
    response_log_t log = { 0 };
    uint8_t challenge[CARD_AUTH_CHALLENGE_SIZE];
    uint8_t successful_challenge[CARD_AUTH_CHALLENGE_SIZE];
    uint8_t first_response[CARD_AUTH_RESPONSE_SIZE];
    uint8_t i;
    assert(card_store_init(&store, &backend) == CARD_STORE_OK);
    credential.permission_id = 7U;
    credential.organization_id = 100U;
    credential.scope_type = CARD_SCOPE_CHECKPOINT;
    credential.scope_id = 9U;
    credential.valid_from = 900U;
    credential.valid_to = 1100U;
    credential.usage_limit = 7U;
    credential.credential_version = 3U;
    credential.key_version = 2U;
    credential.state = CARD_CREDENTIAL_ACTIVE;
    for (i = 0U; i < CARD_KEY_SIZE; ++i) credential.key[i] = (uint8_t)(0x40U + i);
    assert(card_store_upsert(&store, &credential) == CARD_STORE_OK);
    card_auth_init(&auth, &store, 0xC0000001U, 0xB001B001U, capture, &log);
    make_challenge(&credential, 11U, 5U, 1000U, challenge);
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) == CARD_AUTH_OK);
    assert(log.type == AB_MSG_AUTH_RESPONSE && log.length == CARD_AUTH_RESPONSE_SIZE);
    assert(log.payload[8] == CARD_AUTH_OK && read_u32(&log.payload[16]) == 6U);
    assert(card_store_get(&store, credential.permission_id, &persisted) == CARD_STORE_OK);
    assert(persisted.usage_count == 6U);
    assert(auth.store_failures == 0U && auth.usage_commits == 1U);
    assert(auth.send_failures == 0U);
    assert(card_store_init(&rebooted, &backend) == CARD_STORE_OK);
    assert(card_store_get(&rebooted, credential.permission_id, &persisted) == CARD_STORE_OK);
    assert(persisted.usage_count == 6U);
    (void)memcpy(first_response, log.payload, sizeof(first_response));
    log.fail_next = true;
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) ==
           CARD_AUTH_INTERNAL);
    assert(auth.send_failures == 1U && auth.usage_commits == 1U);
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) == CARD_AUTH_OK);
    assert(memcmp(first_response, log.payload, sizeof(first_response)) == 0);
    assert(auth.duplicate_challenges == 2U && auth.successful_responses == 1U);

    make_challenge(&credential, 11U, 6U, 1000U, challenge);
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) == CARD_AUTH_REPLAY);
    assert(log.payload[8] == CARD_AUTH_REPLAY && auth.replay_rejections == 1U);

    make_challenge(&credential, 12U, 6U, 1000U, challenge);
    challenge[63] ^= 1U;
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) == CARD_AUTH_DENIED);
    assert(log.payload[8] == CARD_AUTH_DENIED);

    make_challenge(&credential, 13U, 6U, 1200U, challenge);
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) == CARD_AUTH_DENIED);
    assert(log.payload[8] == CARD_AUTH_DENIED);

    memory.fail_next_write = true;
    make_challenge(&credential, 16U, 6U, 1000U, challenge);
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) == CARD_AUTH_INTERNAL);
    assert(log.payload[8] == CARD_AUTH_INTERNAL);
    assert(card_store_get(&store, credential.permission_id, &persisted) == CARD_STORE_OK);
    assert(persisted.usage_count == 6U);
    assert(auth.store_failures == 1U && auth.usage_commits == 1U);

    make_challenge(&credential, 14U, 6U, 1000U, challenge);
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) == CARD_AUTH_OK);
    (void)memcpy(successful_challenge, challenge, sizeof(successful_challenge));
    assert(log.payload[8] == CARD_AUTH_OK && read_u32(&log.payload[16]) == 7U);
    assert(card_store_get(&store, credential.permission_id, &persisted) == CARD_STORE_OK);
    assert(persisted.usage_count == 7U);
    assert(auth.usage_commits == 2U);
    make_challenge(&credential, 15U, 7U, 1000U, challenge);
    assert(card_auth_handle_challenge(&auth, challenge, sizeof(challenge)) == CARD_AUTH_DENIED);
    assert(log.payload[8] == CARD_AUTH_DENIED);
    assert(card_store_set_state(&store, credential.permission_id,
                                CARD_CREDENTIAL_FROZEN) == CARD_STORE_OK);
    assert(card_auth_handle_challenge(&auth, successful_challenge,
                                      sizeof(successful_challenge)) == CARD_AUTH_DENIED);
    assert(log.payload[8] == CARD_AUTH_DENIED);
}

int main(void)
{
    test_rfc4231_hmac();
    test_authentication_and_replay();
    puts("All Card HMAC-SHA256 authentication and replay tests passed.");
    return 0;
}
