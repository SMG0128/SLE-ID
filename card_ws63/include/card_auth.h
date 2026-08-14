#ifndef SLE_CARD_AUTH_H
#define SLE_CARD_AUTH_H

#include <stdbool.h>
#include <stdint.h>

#include "card_service.h"
#include "credential_store.h"

#define CARD_AUTH_CHALLENGE_BODY_SIZE 48U
#define CARD_AUTH_CHALLENGE_SIZE 64U
#define CARD_AUTH_RESPONSE_BODY_SIZE 32U
#define CARD_AUTH_RESPONSE_SIZE 48U
#define CARD_AUTH_TAG_SIZE 16U
#define CARD_AUTH_NONCE_SIZE 12U
#define CARD_AUTH_CACHE_SIZE 4U

typedef enum {
    CARD_AUTH_OK = 0,
    CARD_AUTH_DENIED = 1,
    CARD_AUTH_BAD_CHALLENGE = 2,
    CARD_AUTH_REPLAY = 3,
    CARD_AUTH_INTERNAL = 4
} card_auth_status_t;

typedef struct {
    bool valid;
    uint32_t session_id;
    uint8_t challenge[CARD_AUTH_CHALLENGE_SIZE];
    uint8_t response[CARD_AUTH_RESPONSE_SIZE];
} card_auth_cache_entry_t;

typedef struct {
    card_store_t *store;
    card_service_send_fn send;
    void *user;
    uint32_t card_id;
    uint32_t boot_id;
    card_auth_cache_entry_t cache[CARD_AUTH_CACHE_SIZE];
    uint8_t cache_next;
    uint32_t challenges_received;
    uint32_t successful_responses;
    uint32_t denied_responses;
    uint32_t duplicate_challenges;
    uint32_t replay_rejections;
    uint32_t usage_commits;
    uint32_t store_failures;
    uint32_t send_failures;
} card_authenticator_t;

void card_auth_init(card_authenticator_t *auth, card_store_t *store,
                    uint32_t card_id, uint32_t boot_id,
                    card_service_send_fn send, void *user);
card_auth_status_t card_auth_handle_challenge(card_authenticator_t *auth,
                                               const uint8_t *payload,
                                               uint16_t payload_length);

#endif
