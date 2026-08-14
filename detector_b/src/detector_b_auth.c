#include "detector_b_auth.h"

#include <string.h>

#include "ab_protocol.h"

#define AUTH_CHALLENGE_BODY_SIZE 48U
#define AUTH_RESPONSE_BODY_SIZE 32U

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

static bool constant_time_equal(const uint8_t *left, const uint8_t *right, size_t length)
{
    uint8_t difference = 0U;
    size_t i;
    for (i = 0U; i < length; ++i) difference |= left[i] ^ right[i];
    return difference == 0U;
}

static bool key_present(const uint8_t *key)
{
    uint8_t aggregate = 0U;
    uint8_t i;
    for (i = 0U; i < DETECTOR_B_AUTH_KEY_SIZE; ++i) aggregate |= key[i];
    return aggregate != 0U;
}

static bool time_reached(uint32_t now_ms, uint32_t deadline_ms)
{
    return (int32_t)(now_ms - deadline_ms) >= 0;
}

static ab_reason_t credential_reason(const detector_b_auth_credential_t *credential,
                                     const detector_b_auth_request_t *request)
{
    if (credential->organization_id != request->organization_id) return AB_REASON_OUT_OF_SCOPE;
    if (credential->state == DETECTOR_B_CREDENTIAL_FROZEN) return AB_REASON_FROZEN;
    if (credential->state == DETECTOR_B_CREDENTIAL_LOST) return AB_REASON_LOST;
    if (credential->state == DETECTOR_B_CREDENTIAL_EXPIRED) return AB_REASON_EXPIRED;
    if (credential->state == DETECTOR_B_CREDENTIAL_REVOKED) return AB_REASON_REVOKED;
    if (credential->valid_from != 0U && request->unix_time < credential->valid_from)
        return AB_REASON_NOT_YET_VALID;
    if (credential->valid_to != 0U && request->unix_time > credential->valid_to)
        return AB_REASON_EXPIRED;
    if (credential->highest_counter >= credential->usage_limit)
        return AB_REASON_USAGE_EXHAUSTED;
    return AB_REASON_NONE;
}

static int find_credential(const detector_b_auth_t *auth, uint32_t permission_id)
{
    uint8_t i;
    for (i = 0U; i < auth->credential_count; ++i)
        if (auth->credentials[i].permission_id == permission_id) return (int)i;
    return -1;
}

static detector_b_auth_session_t *find_session(detector_b_auth_t *auth, uint32_t session_id)
{
    uint8_t i;
    for (i = 0U; i < DETECTOR_B_AUTH_MAX_SESSIONS; ++i)
        if (auth->sessions[i].valid && auth->sessions[i].session_id == session_id)
            return &auth->sessions[i];
    return NULL;
}

static detector_b_auth_session_t *allocate_session(detector_b_auth_t *auth, uint32_t now_ms)
{
    uint8_t i;
    for (i = 0U; i < DETECTOR_B_AUTH_MAX_SESSIONS; ++i) {
        detector_b_auth_session_t *session = &auth->sessions[i];
        if (!session->valid || time_reached(now_ms, session->expires_ms)) {
            if (session->valid && !session->completed) auth->expired_sessions++;
            (void)memset(session, 0, sizeof(*session));
            return session;
        }
    }
    for (i = 0U; i < DETECTOR_B_AUTH_MAX_SESSIONS; ++i) {
        detector_b_auth_session_t *session = &auth->sessions[i];
        if (session->completed) {
            (void)memset(session, 0, sizeof(*session));
            return session;
        }
    }
    return NULL;
}

static bool random_session_id(detector_b_auth_t *auth, uint32_t *session_id)
{
    uint8_t attempts;
    for (attempts = 0U; attempts < 4U; ++attempts) {
        uint8_t bytes[4];
        if (!auth->random(bytes, sizeof(bytes), auth->user)) return false;
        *session_id = read_u32(bytes);
        if (*session_id != 0U && find_session(auth, *session_id) == NULL) return true;
    }
    return false;
}

static bool random_nonce(detector_b_auth_t *auth, uint8_t *nonce)
{
    uint8_t aggregate = 0U;
    uint8_t i;
    if (!auth->random(nonce, 12U, auth->user)) return false;
    for (i = 0U; i < 12U; ++i) aggregate |= nonce[i];
    return aggregate != 0U;
}

static void challenge_tag(detector_b_auth_t *auth, const uint8_t *key,
                          const uint8_t *challenge, uint8_t *tag)
{
    uint8_t material[sizeof(g_challenge_domain) - 1U + 1U + AUTH_CHALLENGE_BODY_SIZE];
    uint8_t digest[32];
    size_t offset = 0U;
    (void)memcpy(&material[offset], g_challenge_domain, sizeof(g_challenge_domain) - 1U);
    offset += sizeof(g_challenge_domain) - 1U;
    material[offset++] = AB_PROTOCOL_VERSION;
    (void)memcpy(&material[offset], challenge, AUTH_CHALLENGE_BODY_SIZE);
    auth->hmac(key, DETECTOR_B_AUTH_KEY_SIZE, material, sizeof(material), digest);
    (void)memcpy(tag, digest, DETECTOR_B_AUTH_TAG_SIZE);
    (void)memset(digest, 0, sizeof(digest));
    (void)memset(material, 0, sizeof(material));
}

static void response_tag(detector_b_auth_t *auth, const uint8_t *key,
                         const uint8_t *challenge, const uint8_t *response,
                         uint8_t *tag)
{
    uint8_t material[sizeof(g_response_domain) - 1U + 1U +
                     AUTH_CHALLENGE_BODY_SIZE + AUTH_RESPONSE_BODY_SIZE];
    uint8_t digest[32];
    size_t offset = 0U;
    (void)memcpy(&material[offset], g_response_domain, sizeof(g_response_domain) - 1U);
    offset += sizeof(g_response_domain) - 1U;
    material[offset++] = AB_PROTOCOL_VERSION;
    (void)memcpy(&material[offset], challenge, AUTH_CHALLENGE_BODY_SIZE);
    offset += AUTH_CHALLENGE_BODY_SIZE;
    (void)memcpy(&material[offset], response, AUTH_RESPONSE_BODY_SIZE);
    auth->hmac(key, DETECTOR_B_AUTH_KEY_SIZE, material, sizeof(material), digest);
    (void)memcpy(tag, digest, DETECTOR_B_AUTH_TAG_SIZE);
    (void)memset(digest, 0, sizeof(digest));
    (void)memset(material, 0, sizeof(material));
}

void detector_b_auth_init(detector_b_auth_t *auth, uint32_t detector_id,
                          detector_b_auth_random_fn random,
                          detector_b_auth_hmac_fn hmac, void *user)
{
    if (auth == NULL) return;
    (void)memset(auth, 0, sizeof(*auth));
    auth->detector_id = detector_id;
    auth->random = random;
    auth->hmac = hmac;
    auth->user = user;
}

bool detector_b_auth_upsert(detector_b_auth_t *auth,
                            const detector_b_auth_credential_t *credential)
{
    int index;
    if (auth == NULL || credential == NULL || credential->permission_id == 0U ||
        credential->organization_id == 0U || credential->usage_limit == 0U ||
        credential->highest_counter > credential->usage_limit ||
        credential->credential_version == 0U || credential->key_version == 0U ||
        !key_present(credential->key) ||
        credential->state > DETECTOR_B_CREDENTIAL_REVOKED ||
        (credential->valid_to != 0U && credential->valid_from > credential->valid_to))
        return false;
    index = find_credential(auth, credential->permission_id);
    if (index >= 0) {
        detector_b_auth_credential_t updated = *credential;
        const detector_b_auth_credential_t *current = &auth->credentials[index];
        uint8_t session_index;
        for (session_index = 0U; session_index < DETECTOR_B_AUTH_MAX_SESSIONS;
             ++session_index) {
            const detector_b_auth_session_t *session = &auth->sessions[session_index];
            if (session->valid && !session->completed &&
                session->credential_index == (uint8_t)index)
                return false;
        }
        if (credential->credential_version < current->credential_version ||
            credential->key_version < current->key_version)
            return false;
        if (credential->credential_version == current->credential_version &&
            updated.highest_counter < current->highest_counter)
            updated.highest_counter = current->highest_counter;
        auth->credentials[index] = updated;
        return true;
    }
    if (auth->credential_count >= DETECTOR_B_AUTH_MAX_CREDENTIALS) return false;
    auth->credentials[auth->credential_count++] = *credential;
    return true;
}

bool detector_b_auth_start(detector_b_auth_t *auth,
                           const detector_b_auth_request_t *request,
                           uint32_t now_ms,
                           uint8_t challenge[DETECTOR_B_AUTH_CHALLENGE_SIZE],
                           ab_reason_t *reason)
{
    detector_b_auth_session_t *session;
    detector_b_auth_credential_t *credential;
    ab_reason_t denied_reason;
    uint32_t session_id;
    int index;
    if (reason != NULL) *reason = AB_REASON_BAD_MESSAGE;
    if (auth == NULL || request == NULL || challenge == NULL || auth->random == NULL ||
        auth->hmac == NULL || auth->detector_id == 0U || request->permission_id == 0U ||
        request->organization_id == 0U)
        return false;
    index = find_credential(auth, request->permission_id);
    if (index < 0) {
        if (reason != NULL) *reason = AB_REASON_NO_PERMISSION;
        return false;
    }
    credential = &auth->credentials[index];
    denied_reason = credential_reason(credential, request);
    if (denied_reason != AB_REASON_NONE) {
        if (reason != NULL) *reason = denied_reason;
        return false;
    }
    session = allocate_session(auth, now_ms);
    if (session == NULL) {
        if (reason != NULL) *reason = AB_REASON_BUSY;
        return false;
    }
    if (!random_session_id(auth, &session_id)) return false;
    (void)memset(challenge, 0, DETECTOR_B_AUTH_CHALLENGE_SIZE);
    write_u32(&challenge[0], session_id);
    if (!random_nonce(auth, &challenge[4])) return false;
    write_u32(&challenge[16], auth->detector_id);
    write_u32(&challenge[20], request->organization_id);
    write_u32(&challenge[24], credential->permission_id);
    write_u32(&challenge[28], credential->credential_version);
    write_u32(&challenge[32], credential->key_version);
    write_u32(&challenge[36], credential->highest_counter);
    write_u32(&challenge[40], request->unix_time);
    write_u32(&challenge[44], request->policy_digest);
    challenge_tag(auth, credential->key, challenge, &challenge[AUTH_CHALLENGE_BODY_SIZE]);
    session->valid = true;
    session->credential_index = (uint8_t)index;
    session->session_id = session_id;
    session->expires_ms = now_ms + DETECTOR_B_AUTH_SESSION_TIMEOUT_MS;
    (void)memcpy(session->challenge, challenge, DETECTOR_B_AUTH_CHALLENGE_SIZE);
    auth->challenges_created++;
    if (reason != NULL) *reason = AB_REASON_NONE;
    return true;
}

static void denied_result(ab_auth_result_t *result, uint32_t session_id,
                          uint32_t card_id, uint32_t permission_id,
                          hw_auth_result_t auth, ab_reason_t reason)
{
    (void)memset(result, 0, sizeof(*result));
    result->session_id = session_id;
    result->card_id = card_id;
    result->permission_id = permission_id;
    result->auth = auth;
    result->reason = reason;
}

bool detector_b_auth_verify(detector_b_auth_t *auth,
                            const uint8_t *response, uint16_t response_length,
                            uint32_t now_ms, ab_auth_result_t *result)
{
    detector_b_auth_session_t *session;
    detector_b_auth_credential_t *credential;
    uint8_t expected_tag[DETECTOR_B_AUTH_TAG_SIZE];
    uint32_t session_id;
    uint32_t card_id;
    uint32_t permission_id;
    uint32_t counter;
    if (result != NULL) denied_result(result, 0U, 0U, 0U,
                                      HW_UNAUTHORIZED, AB_REASON_BAD_MESSAGE);
    if (auth == NULL || response == NULL || result == NULL ||
        response_length != DETECTOR_B_AUTH_RESPONSE_SIZE || auth->hmac == NULL)
        return false;
    session_id = read_u32(&response[0]);
    card_id = read_u32(&response[12]);
    permission_id = read_u32(&response[4]);
    session = find_session(auth, session_id);
    if (session == NULL) {
        denied_result(result, session_id, card_id, permission_id,
                      HW_REPLAY_SUSPECTED, AB_REASON_REPLAY_SUSPECTED);
        auth->replay_rejections++;
        return false;
    }
    if (session->completed) {
        if (memcmp(session->response, response, DETECTOR_B_AUTH_RESPONSE_SIZE) == 0) {
            *result = session->result;
            auth->duplicate_responses++;
            return true;
        }
        denied_result(result, session_id, card_id, permission_id,
                      HW_REPLAY_SUSPECTED, AB_REASON_REPLAY_SUSPECTED);
        auth->replay_rejections++;
        return false;
    }
    if (time_reached(now_ms, session->expires_ms)) {
        session->valid = false;
        auth->expired_sessions++;
        denied_result(result, session_id, card_id, permission_id,
                      HW_UNAUTHORIZED, AB_REASON_STALE_REQUEST);
        return false;
    }
    credential = &auth->credentials[session->credential_index];
    if (response[8] != 0U) {
        denied_result(result, session_id, card_id, permission_id,
                      response[8] == 3U ? HW_REPLAY_SUSPECTED : HW_UNAUTHORIZED,
                      response[8] == 3U ? AB_REASON_REPLAY_SUSPECTED : AB_REASON_NO_PERMISSION);
        auth->denied_responses++;
        return false;
    }
    counter = read_u32(&response[16]);
    if (permission_id != credential->permission_id || card_id == 0U ||
        (credential->expected_card_id != 0U && card_id != credential->expected_card_id) ||
        read_u32(&response[20]) != credential->credential_version ||
        read_u32(&response[24]) != credential->key_version || read_u32(&response[28]) == 0U) {
        denied_result(result, session_id, card_id, permission_id,
                      HW_UNAUTHORIZED, AB_REASON_KEY_VERSION_MISMATCH);
        auth->denied_responses++;
        return false;
    }
    response_tag(auth, credential->key, session->challenge, response, expected_tag);
    if (!constant_time_equal(expected_tag, &response[AUTH_RESPONSE_BODY_SIZE],
                             DETECTOR_B_AUTH_TAG_SIZE)) {
        (void)memset(expected_tag, 0, sizeof(expected_tag));
        denied_result(result, session_id, card_id, permission_id,
                      HW_KEY_FAILED, AB_REASON_KEY_FAILED);
        auth->denied_responses++;
        return false;
    }
    (void)memset(expected_tag, 0, sizeof(expected_tag));
    if (counter <= credential->highest_counter || counter > credential->usage_limit) {
        denied_result(result, session_id, card_id, permission_id,
                      HW_REPLAY_SUSPECTED, AB_REASON_REPLAY_SUSPECTED);
        auth->replay_rejections++;
        return false;
    }
    credential->highest_counter = counter;
    denied_result(result, session_id, card_id, permission_id, HW_AUTHORIZED, AB_REASON_NONE);
    result->counter = counter;
    session->completed = true;
    /* The challenge deadline covers the radio/HMAC handshake.  Start a separate
     * passage window only after authentication succeeds, otherwise a slow real
     * SLE exchange can leave no time for Detector A to report the passage. */
    session->expires_ms = now_ms + DETECTOR_B_AUTH_GRANT_TIMEOUT_MS;
    (void)memcpy(session->response, response, DETECTOR_B_AUTH_RESPONSE_SIZE);
    session->result = *result;
    auth->successful_responses++;
    return true;
}

bool detector_b_auth_consume(detector_b_auth_t *auth, uint32_t session_id,
                             uint32_t card_id, uint32_t permission_id,
                             uint32_t counter, uint32_t now_ms)
{
    detector_b_auth_session_t *session;
    if (auth == NULL || session_id == 0U || card_id == 0U || permission_id == 0U ||
        counter == 0U) return false;
    session = find_session(auth, session_id);
    if (session == NULL || !session->completed || session->consumed) {
        auth->replay_rejections++;
        return false;
    }
    if (time_reached(now_ms, session->expires_ms)) {
        session->valid = false;
        auth->expired_sessions++;
        return false;
    }
    if (session->result.auth != HW_AUTHORIZED || session->result.reason != AB_REASON_NONE ||
        session->result.card_id != card_id ||
        session->result.permission_id != permission_id ||
        session->result.counter != counter) {
        auth->replay_rejections++;
        return false;
    }
    session->consumed = true;
    auth->consumed_grants++;
    return true;
}

void detector_b_auth_cancel(detector_b_auth_t *auth, uint32_t session_id)
{
    detector_b_auth_session_t *session;
    if (auth == NULL || session_id == 0U) return;
    session = find_session(auth, session_id);
    if (session != NULL && !session->completed) (void)memset(session, 0, sizeof(*session));
}

void detector_b_auth_tick(detector_b_auth_t *auth, uint32_t now_ms)
{
    uint8_t i;
    if (auth == NULL) return;
    for (i = 0U; i < DETECTOR_B_AUTH_MAX_SESSIONS; ++i) {
        detector_b_auth_session_t *session = &auth->sessions[i];
        if (session->valid && !session->completed && time_reached(now_ms, session->expires_ms)) {
            session->valid = false;
            auth->expired_sessions++;
        }
    }
}
