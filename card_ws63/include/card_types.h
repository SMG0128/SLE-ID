#ifndef SLE_CARD_TYPES_H
#define SLE_CARD_TYPES_H

#include <stdint.h>

#define CARD_MAX_CREDENTIALS 8U
#define CARD_KEY_SIZE 32U
#define CARD_CREDENTIAL_WIRE_SIZE 78U

typedef enum {
    CARD_CREDENTIAL_ACTIVE = 0,
    CARD_CREDENTIAL_FROZEN = 1,
    CARD_CREDENTIAL_LOST = 2,
    CARD_CREDENTIAL_EXPIRED = 3,
    CARD_CREDENTIAL_REVOKED = 4
} card_credential_state_t;

typedef enum {
    CARD_SCOPE_GLOBAL = 0,
    CARD_SCOPE_ORGANIZATION = 1,
    CARD_SCOPE_SITE = 2,
    CARD_SCOPE_CHECKPOINT = 3
} card_scope_type_t;

typedef struct {
    uint32_t permission_id;
    uint32_t organization_id;
    card_scope_type_t scope_type;
    uint32_t scope_id;
    uint32_t valid_from;
    uint32_t valid_to;
    uint32_t policy_flags;
    uint32_t usage_limit;
    uint32_t usage_count;
    uint32_t credential_version;
    uint32_t key_version;
    uint8_t key[CARD_KEY_SIZE];
    card_credential_state_t state;
} card_credential_t;

#endif
