#ifndef SLE_WS63_CARD_NV_PORT_H
#define SLE_WS63_CARD_NV_PORT_H

#include <stdint.h>

#include "credential_store.h"

#define WS63_CARD_NV_KEY_NAMESPACE_START 0x5C00U
#define WS63_CARD_NV_KEY_NAMESPACE_END 0x5CFFU
#define WS63_CARD_NV_SLOT_A_DEFAULT_KEY 0x5C10U
#define WS63_CARD_NV_SLOT_B_DEFAULT_KEY 0x5C11U

typedef struct {
    uint16_t slot_keys[CARD_STORE_SLOT_COUNT];
} ws63_card_nv_context_t;

bool ws63_card_nv_keys_valid(uint16_t slot_a_key, uint16_t slot_b_key);
bool ws63_card_nv_backend_init(card_store_backend_t *backend, ws63_card_nv_context_t *context,
                               uint16_t slot_a_key, uint16_t slot_b_key);

#endif
