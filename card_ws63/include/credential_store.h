#ifndef SLE_CARD_CREDENTIAL_STORE_H
#define SLE_CARD_CREDENTIAL_STORE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "card_types.h"

#define CARD_STORE_SLOT_COUNT 2U
#define CARD_STORE_SLOT_SIZE 768U

typedef bool (*card_store_read_slot_fn)(uint8_t slot, uint8_t *data, size_t length, void *user);
typedef bool (*card_store_write_slot_fn)(uint8_t slot, const uint8_t *data, size_t length, void *user);

typedef struct {
    card_store_read_slot_fn read_slot;
    card_store_write_slot_fn write_slot;
    void *user;
} card_store_backend_t;

typedef enum {
    CARD_STORE_OK = 0,
    CARD_STORE_INVALID_ARGUMENT,
    CARD_STORE_NOT_FOUND,
    CARD_STORE_FULL,
    CARD_STORE_IO_ERROR,
    CARD_STORE_VERIFY_ERROR,
    CARD_STORE_USAGE_EXHAUSTED,
    CARD_STORE_NOT_INITIALIZED
} card_store_result_t;

typedef struct {
    card_store_backend_t backend;
    card_credential_t credentials[CARD_MAX_CREDENTIALS];
    uint32_t generation;
    uint8_t credential_count;
    uint8_t active_slot;
    bool initialized;
} card_store_t;

bool card_credential_validate(const card_credential_t *credential);
size_t card_credential_encode(const card_credential_t *credential, uint8_t *output,
                              size_t capacity);
bool card_credential_decode(const uint8_t *data, size_t length,
                            card_credential_t *credential);
card_store_result_t card_store_init(card_store_t *store, const card_store_backend_t *backend);
card_store_result_t card_store_upsert(card_store_t *store, const card_credential_t *credential);
card_store_result_t card_store_get(const card_store_t *store, uint32_t permission_id,
                                   card_credential_t *credential);
size_t card_store_list(const card_store_t *store, card_credential_t *out, size_t capacity);
card_store_result_t card_store_set_state(card_store_t *store, uint32_t permission_id,
                                         card_credential_state_t state);
card_store_result_t card_store_consume_usage(card_store_t *store, uint32_t permission_id,
                                             uint32_t minimum_counter,
                                             uint32_t *consumed_counter);
uint32_t card_store_crc32(const uint8_t *data, size_t length);

#endif
