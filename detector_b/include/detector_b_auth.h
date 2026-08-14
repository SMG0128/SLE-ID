#ifndef SLE_DETECTOR_B_AUTH_H
#define SLE_DETECTOR_B_AUTH_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "ab_messages.h"

#define DETECTOR_B_AUTH_KEY_SIZE 32U
#define DETECTOR_B_AUTH_TAG_SIZE 16U
#define DETECTOR_B_AUTH_CHALLENGE_SIZE 64U
#define DETECTOR_B_AUTH_RESPONSE_SIZE 48U
#define DETECTOR_B_AUTH_MAX_CREDENTIALS 8U
#define DETECTOR_B_AUTH_MAX_SESSIONS 4U
#define DETECTOR_B_AUTH_SESSION_TIMEOUT_MS 5000U
#define DETECTOR_B_AUTH_GRANT_TIMEOUT_MS 15000U

typedef enum {
    DETECTOR_B_CREDENTIAL_ACTIVE = 0,
    DETECTOR_B_CREDENTIAL_FROZEN = 1,
    DETECTOR_B_CREDENTIAL_LOST = 2,
    DETECTOR_B_CREDENTIAL_EXPIRED = 3,
    DETECTOR_B_CREDENTIAL_REVOKED = 4
} detector_b_credential_state_t;

typedef struct {
    uint32_t permission_id;
    uint32_t organization_id;
    uint32_t expected_card_id;
    uint32_t valid_from;
    uint32_t valid_to;
    uint32_t usage_limit;
    uint32_t highest_counter;
    uint32_t credential_version;
    uint32_t key_version;
    detector_b_credential_state_t state;
    uint8_t key[DETECTOR_B_AUTH_KEY_SIZE];
} detector_b_auth_credential_t;

typedef struct {
    uint32_t organization_id;
    uint32_t permission_id;
    uint32_t unix_time;
    uint32_t policy_digest;
} detector_b_auth_request_t;

typedef bool (*detector_b_auth_random_fn)(uint8_t *output, size_t length, void *user);
typedef void (*detector_b_auth_hmac_fn)(const uint8_t *key, size_t key_length,
                                       const uint8_t *data, size_t data_length,
                                       uint8_t output[32]);

typedef struct {
    bool valid;
    bool completed;
    bool consumed;
    uint8_t credential_index;
    uint32_t session_id;
    uint32_t expires_ms;
    uint8_t challenge[DETECTOR_B_AUTH_CHALLENGE_SIZE];
    uint8_t response[DETECTOR_B_AUTH_RESPONSE_SIZE];
    ab_auth_result_t result;
} detector_b_auth_session_t;

typedef struct {
    uint32_t detector_id;
    detector_b_auth_random_fn random;
    detector_b_auth_hmac_fn hmac;
    void *user;
    detector_b_auth_credential_t credentials[DETECTOR_B_AUTH_MAX_CREDENTIALS];
    uint8_t credential_count;
    detector_b_auth_session_t sessions[DETECTOR_B_AUTH_MAX_SESSIONS];
    uint32_t challenges_created;
    uint32_t successful_responses;
    uint32_t duplicate_responses;
    uint32_t denied_responses;
    uint32_t replay_rejections;
    uint32_t expired_sessions;
    uint32_t consumed_grants;
} detector_b_auth_t;

void detector_b_auth_init(detector_b_auth_t *auth, uint32_t detector_id,
                          detector_b_auth_random_fn random,
                          detector_b_auth_hmac_fn hmac, void *user);
bool detector_b_auth_upsert(detector_b_auth_t *auth,
                            const detector_b_auth_credential_t *credential);
bool detector_b_auth_start(detector_b_auth_t *auth,
                           const detector_b_auth_request_t *request,
                           uint32_t now_ms,
                           uint8_t challenge[DETECTOR_B_AUTH_CHALLENGE_SIZE],
                           ab_reason_t *reason);
bool detector_b_auth_verify(detector_b_auth_t *auth,
                            const uint8_t *response, uint16_t response_length,
                            uint32_t now_ms, ab_auth_result_t *result);
bool detector_b_auth_consume(detector_b_auth_t *auth, uint32_t session_id,
                             uint32_t card_id, uint32_t permission_id,
                             uint32_t counter, uint32_t now_ms);
void detector_b_auth_cancel(detector_b_auth_t *auth, uint32_t session_id);
void detector_b_auth_tick(detector_b_auth_t *auth, uint32_t now_ms);

#endif
