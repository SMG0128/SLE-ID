#include "ws63_card_nv_port.h"

#include "nv.h"
#include "nv_config.h"

#if CARD_STORE_SLOT_SIZE > NV_NORMAL_KVALUE_MAX_LEN
#error "Card credential slot exceeds the WS63 normal NV value limit"
#endif

bool ws63_card_nv_keys_valid(uint16_t slot_a_key, uint16_t slot_b_key)
{
    return slot_a_key >= WS63_CARD_NV_KEY_NAMESPACE_START &&
           slot_a_key <= WS63_CARD_NV_KEY_NAMESPACE_END &&
           slot_b_key >= WS63_CARD_NV_KEY_NAMESPACE_START &&
           slot_b_key <= WS63_CARD_NV_KEY_NAMESPACE_END &&
           slot_a_key != slot_b_key;
}

static bool read_slot(uint8_t slot, uint8_t *data, size_t length, void *user)
{
    ws63_card_nv_context_t *context = (ws63_card_nv_context_t *)user;
    uint16_t actual_length = 0U;
    if (context == NULL || data == NULL || slot >= CARD_STORE_SLOT_COUNT ||
        length != CARD_STORE_SLOT_SIZE || length > NV_NORMAL_KVALUE_MAX_LEN)
        return false;
    return uapi_nv_read(context->slot_keys[slot], (uint16_t)length, &actual_length, data) == ERRCODE_SUCC &&
           actual_length == (uint16_t)length;
}

static bool write_slot(uint8_t slot, const uint8_t *data, size_t length, void *user)
{
    ws63_card_nv_context_t *context = (ws63_card_nv_context_t *)user;
    if (context == NULL || data == NULL || slot >= CARD_STORE_SLOT_COUNT ||
        length != CARD_STORE_SLOT_SIZE || length > NV_NORMAL_KVALUE_MAX_LEN)
        return false;
    return uapi_nv_write(context->slot_keys[slot], data, (uint16_t)length) == ERRCODE_SUCC;
}

bool ws63_card_nv_backend_init(card_store_backend_t *backend, ws63_card_nv_context_t *context,
                               uint16_t slot_a_key, uint16_t slot_b_key)
{
    if (backend == NULL || context == NULL ||
        !ws63_card_nv_keys_valid(slot_a_key, slot_b_key))
        return false;
    context->slot_keys[0] = slot_a_key;
    context->slot_keys[1] = slot_b_key;
    backend->read_slot = read_slot;
    backend->write_slot = write_slot;
    backend->user = context;
    return true;
}
