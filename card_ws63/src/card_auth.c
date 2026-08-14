#include "card_auth.h"

#include <limits.h>
#include <string.h>

#include "card_crypto.h"

static const uint8_t g_challenge_domain[] = "SLE-AUTH-CHAL-V1";
static const uint8_t g_response_domain[] = "SLE-AUTH-RESP-V1";

static uint32_t read_u32(const uint8_t *data)
{
    return (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
           ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
}

static void write_u32(uint8_t *data, uint32_t value)
{
    data[0] = (uint8_t)value;
    data[1] = (uint8_t)(value >> 8);
    data[2] = (uint8_t)(value >> 16);
    data[3] = (uint8_t)(value >> 24);
}

static void calculate_challenge_tag(const uint8_t key[CARD_KEY_SIZE],
                                    const uint8_t *body, uint8_t *tag)
{
    uint8_t material[sizeof(g_challenge_domain) - 1U + 1U + CARD_AUTH_CHALLENGE_BODY_SIZE];
    uint8_t digest[CARD_SHA256_SIZE];
    size_t offset = 0U;
    (void)memcpy(&material[offset], g_challenge_domain, sizeof(g_challenge_domain) - 1U);
    offset += sizeof(g_challenge_domain) - 1U;
    material[offset++] = AB_PROTOCOL_VERSION;
    (void)memcpy(&material[offset], body, CARD_AUTH_CHALLENGE_BODY_SIZE);
    card_hmac_sha256(key, CARD_KEY_SIZE, material, sizeof(material), digest);
    (void)memcpy(tag, digest, CARD_AUTH_TAG_SIZE);
    (void)memset(digest, 0, sizeof(digest));
    (void)memset(material, 0, sizeof(material));
}

static void calculate_response_tag(const uint8_t key[CARD_KEY_SIZE],
                                   const uint8_t *challenge_body,
                                   const uint8_t *response_body, uint8_t *tag)
{
    uint8_t material[sizeof(g_response_domain) - 1U + 1U +
                     CARD_AUTH_CHALLENGE_BODY_SIZE + CARD_AUTH_RESPONSE_BODY_SIZE];
    uint8_t digest[CARD_SHA256_SIZE];
    size_t offset = 0U;
    (void)memcpy(&material[offset], g_response_domain, sizeof(g_response_domain) - 1U);
    offset += sizeof(g_response_domain) - 1U;
    material[offset++] = AB_PROTOCOL_VERSION;
    (void)memcpy(&material[offset], challenge_body, CARD_AUTH_CHALLENGE_BODY_SIZE);
    offset += CARD_AUTH_CHALLENGE_BODY_SIZE;
    (void)memcpy(&material[offset], response_body, CARD_AUTH_RESPONSE_BODY_SIZE);
    card_hmac_sha256(key, CARD_KEY_SIZE, material, sizeof(material), digest);
    (void)memcpy(tag, digest, CARD_AUTH_TAG_SIZE);
    (void)memset(digest, 0, sizeof(digest));
    (void)memset(material, 0, sizeof(material));
}

static bool nonce_valid(const uint8_t *nonce)
{
    uint8_t aggregate = 0U;
    uint8_t i;
    for (i = 0U; i < CARD_AUTH_NONCE_SIZE; ++i) aggregate |= nonce[i];
    return aggregate != 0U;
}

static card_auth_cache_entry_t *find_session(card_authenticator_t *auth, uint32_t session_id)
{
    uint8_t i;
    for (i = 0U; i < CARD_AUTH_CACHE_SIZE; ++i)
        if (auth->cache[i].valid && auth->cache[i].session_id == session_id)
            return &auth->cache[i];
    return NULL;
}

static bool cached_credential_still_valid(card_authenticator_t *auth,
                                          const card_auth_cache_entry_t *cached)
{
    card_credential_t credential;
    bool valid;
    if (card_store_get(auth->store, read_u32(&cached->response[4]), &credential) !=
        CARD_STORE_OK)
        return false;
    valid = credential.state == CARD_CREDENTIAL_ACTIVE &&
            credential.credential_version == read_u32(&cached->response[20]) &&
            credential.key_version == read_u32(&cached->response[24]);
    (void)memset(&credential, 0, sizeof(credential));
    return valid;
}

static card_auth_status_t send_response(card_authenticator_t *auth, const uint8_t *response)
{
    if (auth->send == NULL ||
        !auth->send(AB_MSG_AUTH_RESPONSE, AB_FLAG_RESPONSE, response,
                    CARD_AUTH_RESPONSE_SIZE, auth->user)) {
        auth->send_failures++;
        return CARD_AUTH_INTERNAL;
    }
    return (card_auth_status_t)response[8];
}

static card_auth_status_t send_unsigned_error(card_authenticator_t *auth,
                                              uint32_t session_id,
                                              uint32_t permission_id,
                                              card_auth_status_t status)
{
    uint8_t response[CARD_AUTH_RESPONSE_SIZE] = { 0U };
    write_u32(&response[0], session_id);
    write_u32(&response[4], permission_id);
    response[8] = (uint8_t)status;
    write_u32(&response[12], auth->card_id);
    write_u32(&response[28], auth->boot_id);
    auth->denied_responses++;
    return send_response(auth, response);
}

void card_auth_init(card_authenticator_t *auth, card_store_t *store,
                    uint32_t card_id, uint32_t boot_id,
                    card_service_send_fn send, void *user)
{
    if (auth == NULL) return;
    (void)memset(auth, 0, sizeof(*auth));
    auth->store = store;
    auth->card_id = card_id;
    auth->boot_id = boot_id;
    auth->send = send;
    auth->user = user;
}

card_auth_status_t card_auth_handle_challenge(card_authenticator_t *auth,
                                               const uint8_t *payload,
                                               uint16_t payload_length)
{
    uint8_t expected_tag[CARD_AUTH_TAG_SIZE];
    uint8_t response[CARD_AUTH_RESPONSE_SIZE] = { 0U };
    card_credential_t credential;
    card_auth_cache_entry_t *cached;
    card_store_result_t consume_result;
    uint32_t consumed_counter;
    uint32_t session_id;
    uint32_t organization_id;
    uint32_t permission_id;
    uint32_t credential_version;
    uint32_t key_version;
    uint32_t minimum_counter;
    uint32_t unix_time;
    if (auth == NULL || auth->store == NULL || payload == NULL ||
        payload_length != CARD_AUTH_CHALLENGE_SIZE)
        return CARD_AUTH_BAD_CHALLENGE;
    auth->challenges_received++;
    session_id = read_u32(&payload[0]);
    organization_id = read_u32(&payload[20]);
    permission_id = read_u32(&payload[24]);
    credential_version = read_u32(&payload[28]);
    key_version = read_u32(&payload[32]);
    minimum_counter = read_u32(&payload[36]);
    unix_time = read_u32(&payload[40]);
    if (session_id == 0U || read_u32(&payload[16]) == 0U || organization_id == 0U ||
        permission_id == 0U || !nonce_valid(&payload[4]))
        return send_unsigned_error(auth, session_id, permission_id, CARD_AUTH_BAD_CHALLENGE);
    cached = find_session(auth, session_id);
    if (cached != NULL) {
        if (memcmp(cached->challenge, payload, CARD_AUTH_CHALLENGE_SIZE) == 0) {
            if (!cached_credential_still_valid(auth, cached)) {
                return send_unsigned_error(auth, session_id, permission_id,
                                           CARD_AUTH_DENIED);
            }
            auth->duplicate_challenges++;
            return send_response(auth, cached->response);
        }
        auth->replay_rejections++;
        return send_unsigned_error(auth, session_id, permission_id, CARD_AUTH_REPLAY);
    }
    if (card_store_get(auth->store, permission_id, &credential) != CARD_STORE_OK)
        return send_unsigned_error(auth, session_id, permission_id, CARD_AUTH_DENIED);
    if (credential.organization_id != organization_id ||
        credential.credential_version != credential_version ||
        credential.key_version != key_version || credential.state != CARD_CREDENTIAL_ACTIVE ||
        (credential.valid_from != 0U && unix_time < credential.valid_from) ||
        (credential.valid_to != 0U && unix_time > credential.valid_to) ||
        credential.usage_count >= credential.usage_limit) {
        (void)memset(&credential, 0, sizeof(credential));
        return send_unsigned_error(auth, session_id, permission_id, CARD_AUTH_DENIED);
    }
    calculate_challenge_tag(credential.key, payload, expected_tag);
    if (!card_constant_time_equal(expected_tag, &payload[CARD_AUTH_CHALLENGE_BODY_SIZE],
                                  CARD_AUTH_TAG_SIZE)) {
        (void)memset(expected_tag, 0, sizeof(expected_tag));
        (void)memset(&credential, 0, sizeof(credential));
        return send_unsigned_error(auth, session_id, permission_id, CARD_AUTH_DENIED);
    }
    (void)memset(expected_tag, 0, sizeof(expected_tag));
    consume_result = card_store_consume_usage(auth->store, permission_id,
                                              minimum_counter, &consumed_counter);
    if (consume_result == CARD_STORE_USAGE_EXHAUSTED) {
        (void)memset(&credential, 0, sizeof(credential));
        return send_unsigned_error(auth, session_id, permission_id, CARD_AUTH_DENIED);
    }
    if (consume_result != CARD_STORE_OK) {
        auth->store_failures++;
        (void)memset(&credential, 0, sizeof(credential));
        return send_unsigned_error(auth, session_id, permission_id, CARD_AUTH_INTERNAL);
    }
    auth->usage_commits++;
    write_u32(&response[0], session_id);
    write_u32(&response[4], permission_id);
    response[8] = CARD_AUTH_OK;
    write_u32(&response[12], auth->card_id);
    write_u32(&response[16], consumed_counter);
    write_u32(&response[20], credential.credential_version);
    write_u32(&response[24], credential.key_version);
    write_u32(&response[28], auth->boot_id);
    calculate_response_tag(credential.key, payload, response, &response[32]);
    cached = &auth->cache[auth->cache_next];
    cached->valid = true;
    cached->session_id = session_id;
    (void)memcpy(cached->challenge, payload, CARD_AUTH_CHALLENGE_SIZE);
    (void)memcpy(cached->response, response, CARD_AUTH_RESPONSE_SIZE);
    auth->cache_next = (uint8_t)((auth->cache_next + 1U) % CARD_AUTH_CACHE_SIZE);
    auth->successful_responses++;
    (void)memset(&credential, 0, sizeof(credential));
    return send_response(auth, response);
}
