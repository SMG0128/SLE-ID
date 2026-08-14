#include "credential_store.h"

#include <limits.h>
#include <string.h>

#define CARD_STORE_MAGIC 0x31445243U
#define CARD_STORE_SCHEMA_VERSION 1U
#define CARD_STORE_HEADER_SIZE 16U
#define CARD_STORE_ENTRY_SIZE CARD_CREDENTIAL_WIRE_SIZE

static uint16_t read_u16(const uint8_t *p)
{
    return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));
}

static uint32_t read_u32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void write_u16(uint8_t *p, uint16_t value)
{
    p[0] = (uint8_t)value;
    p[1] = (uint8_t)(value >> 8);
}

static void write_u32(uint8_t *p, uint32_t value)
{
    p[0] = (uint8_t)value;
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)(value >> 16);
    p[3] = (uint8_t)(value >> 24);
}

uint32_t card_store_crc32(const uint8_t *data, size_t length)
{
    uint32_t crc = 0xFFFFFFFFU;
    size_t i;
    uint8_t bit;
    if (data == NULL) return 0U;
    for (i = 0U; i < length; ++i) {
        crc ^= data[i];
        for (bit = 0U; bit < 8U; ++bit)
            crc = (crc & 1U) ? (crc >> 1) ^ 0xEDB88320U : crc >> 1;
    }
    return ~crc;
}

static bool key_present(const uint8_t key[CARD_KEY_SIZE])
{
    uint8_t aggregate = 0U;
    uint8_t i;
    for (i = 0U; i < CARD_KEY_SIZE; ++i) aggregate |= key[i];
    return aggregate != 0U;
}

bool card_credential_validate(const card_credential_t *credential)
{
    return credential != NULL && credential->permission_id != 0U &&
           credential->organization_id != 0U && credential->scope_type <= CARD_SCOPE_CHECKPOINT &&
           credential->state <= CARD_CREDENTIAL_REVOKED &&
           (credential->valid_to == 0U || credential->valid_from <= credential->valid_to) &&
           credential->usage_limit != 0U && credential->usage_count <= credential->usage_limit &&
           credential->credential_version != 0U && credential->key_version != 0U &&
           key_present(credential->key);
}

size_t card_credential_encode(const card_credential_t *credential, uint8_t *out,
                              size_t capacity)
{
    if (!card_credential_validate(credential) || out == NULL ||
        capacity < CARD_CREDENTIAL_WIRE_SIZE) return 0U;
    write_u32(&out[0], credential->permission_id);
    write_u32(&out[4], credential->organization_id);
    out[8] = (uint8_t)credential->scope_type;
    write_u32(&out[9], credential->scope_id);
    write_u32(&out[13], credential->valid_from);
    write_u32(&out[17], credential->valid_to);
    write_u32(&out[21], credential->policy_flags);
    write_u32(&out[25], credential->usage_limit);
    write_u32(&out[29], credential->usage_count);
    write_u32(&out[33], credential->credential_version);
    write_u32(&out[37], credential->key_version);
    (void)memcpy(&out[41], credential->key, CARD_KEY_SIZE);
    out[73] = (uint8_t)credential->state;
    (void)memset(&out[74], 0, 4U);
    return CARD_CREDENTIAL_WIRE_SIZE;
}

bool card_credential_decode(const uint8_t *data, size_t length,
                            card_credential_t *credential)
{
    if (data == NULL || credential == NULL || length != CARD_CREDENTIAL_WIRE_SIZE) return false;
    (void)memset(credential, 0, sizeof(*credential));
    credential->permission_id = read_u32(&data[0]);
    credential->organization_id = read_u32(&data[4]);
    credential->scope_type = (card_scope_type_t)data[8];
    credential->scope_id = read_u32(&data[9]);
    credential->valid_from = read_u32(&data[13]);
    credential->valid_to = read_u32(&data[17]);
    credential->policy_flags = read_u32(&data[21]);
    credential->usage_limit = read_u32(&data[25]);
    credential->usage_count = read_u32(&data[29]);
    credential->credential_version = read_u32(&data[33]);
    credential->key_version = read_u32(&data[37]);
    (void)memcpy(credential->key, &data[41], CARD_KEY_SIZE);
    credential->state = (card_credential_state_t)data[73];
    return card_credential_validate(credential);
}

static size_t encode_image(const card_credential_t *credentials, uint8_t count,
                           uint32_t generation, uint8_t *image)
{
    uint16_t payload_length = (uint16_t)((uint16_t)count * CARD_STORE_ENTRY_SIZE);
    size_t crc_offset = CARD_STORE_HEADER_SIZE + payload_length;
    uint8_t i;
    (void)memset(image, 0, CARD_STORE_SLOT_SIZE);
    write_u32(&image[0], CARD_STORE_MAGIC);
    write_u16(&image[4], CARD_STORE_SCHEMA_VERSION);
    image[6] = count;
    write_u32(&image[8], generation);
    write_u16(&image[12], payload_length);
    for (i = 0U; i < count; ++i)
        (void)card_credential_encode(
            &credentials[i], &image[CARD_STORE_HEADER_SIZE + i * CARD_STORE_ENTRY_SIZE],
            CARD_STORE_ENTRY_SIZE);
    write_u32(&image[crc_offset], card_store_crc32(image, crc_offset));
    return crc_offset + 4U;
}

static bool decode_image(const uint8_t *image, card_credential_t *credentials,
                         uint8_t *count, uint32_t *generation)
{
    uint8_t image_count;
    uint16_t payload_length;
    size_t crc_offset;
    uint8_t i;
    if (read_u32(&image[0]) != CARD_STORE_MAGIC ||
        read_u16(&image[4]) != CARD_STORE_SCHEMA_VERSION) return false;
    image_count = image[6];
    payload_length = read_u16(&image[12]);
    if (image_count > CARD_MAX_CREDENTIALS ||
        payload_length != (uint16_t)((uint16_t)image_count * CARD_STORE_ENTRY_SIZE)) return false;
    crc_offset = CARD_STORE_HEADER_SIZE + payload_length;
    if (crc_offset + 4U > CARD_STORE_SLOT_SIZE ||
        read_u32(&image[crc_offset]) != card_store_crc32(image, crc_offset)) return false;
    for (i = 0U; i < image_count; ++i) {
        if (!card_credential_decode(
                &image[CARD_STORE_HEADER_SIZE + i * CARD_STORE_ENTRY_SIZE],
                CARD_STORE_ENTRY_SIZE, &credentials[i])) return false;
    }
    *count = image_count;
    *generation = read_u32(&image[8]);
    return true;
}

card_store_result_t card_store_init(card_store_t *store, const card_store_backend_t *backend)
{
    uint8_t images[CARD_STORE_SLOT_COUNT][CARD_STORE_SLOT_SIZE];
    card_credential_t decoded[CARD_STORE_SLOT_COUNT][CARD_MAX_CREDENTIALS];
    uint32_t generation[CARD_STORE_SLOT_COUNT] = { 0U, 0U };
    uint8_t count[CARD_STORE_SLOT_COUNT] = { 0U, 0U };
    bool valid[CARD_STORE_SLOT_COUNT] = { false, false };
    uint8_t selected = 0U;
    uint8_t slot;
    if (store == NULL || backend == NULL || backend->read_slot == NULL ||
        backend->write_slot == NULL) return CARD_STORE_INVALID_ARGUMENT;
    (void)memset(store, 0, sizeof(*store));
    store->backend = *backend;
    for (slot = 0U; slot < CARD_STORE_SLOT_COUNT; ++slot) {
        if (store->backend.read_slot(slot, images[slot], CARD_STORE_SLOT_SIZE, store->backend.user))
            valid[slot] = decode_image(images[slot], decoded[slot], &count[slot], &generation[slot]);
    }
    if (valid[1] && (!valid[0] || (int32_t)(generation[1] - generation[0]) > 0)) selected = 1U;
    if (valid[selected]) {
        (void)memcpy(store->credentials, decoded[selected],
                     (size_t)count[selected] * sizeof(card_credential_t));
        store->credential_count = count[selected];
        store->generation = generation[selected];
        store->active_slot = selected;
    }
    store->initialized = true;
    return CARD_STORE_OK;
}

static card_store_result_t commit(card_store_t *store, const card_credential_t *credentials,
                                  uint8_t count)
{
    uint8_t image[CARD_STORE_SLOT_SIZE];
    uint8_t verify[CARD_STORE_SLOT_SIZE];
    card_credential_t decoded[CARD_MAX_CREDENTIALS];
    uint8_t decoded_count = 0U;
    uint32_t decoded_generation = 0U;
    uint32_t next_generation;
    uint8_t target_slot = (uint8_t)(store->active_slot ^ 1U);
    if (store->generation == UINT32_MAX) return CARD_STORE_INVALID_ARGUMENT;
    next_generation = store->generation + 1U;
    (void)encode_image(credentials, count, next_generation, image);
    if (!store->backend.write_slot(target_slot, image, CARD_STORE_SLOT_SIZE, store->backend.user))
        return CARD_STORE_IO_ERROR;
    if (!store->backend.read_slot(target_slot, verify, CARD_STORE_SLOT_SIZE, store->backend.user))
        return CARD_STORE_IO_ERROR;
    if (!decode_image(verify, decoded, &decoded_count, &decoded_generation) ||
        decoded_count != count || decoded_generation != next_generation)
        return CARD_STORE_VERIFY_ERROR;
    (void)memcpy(store->credentials, credentials, (size_t)count * sizeof(card_credential_t));
    store->credential_count = count;
    store->generation = next_generation;
    store->active_slot = target_slot;
    return CARD_STORE_OK;
}

card_store_result_t card_store_upsert(card_store_t *store, const card_credential_t *credential)
{
    card_credential_t candidate[CARD_MAX_CREDENTIALS];
    uint8_t count;
    uint8_t i;
    if (store == NULL || !card_credential_validate(credential)) return CARD_STORE_INVALID_ARGUMENT;
    if (!store->initialized) return CARD_STORE_NOT_INITIALIZED;
    count = store->credential_count;
    (void)memcpy(candidate, store->credentials, (size_t)count * sizeof(card_credential_t));
    for (i = 0U; i < count; ++i) {
        if (candidate[i].permission_id == credential->permission_id) {
            uint8_t current_wire[CARD_CREDENTIAL_WIRE_SIZE];
            uint8_t updated_wire[CARD_CREDENTIAL_WIRE_SIZE];
            const card_credential_t *current = &candidate[i];
            if (credential->credential_version < current->credential_version ||
                credential->key_version < current->key_version ||
                credential->usage_count < current->usage_count ||
                (memcmp(credential->key, current->key, CARD_KEY_SIZE) != 0 &&
                 credential->key_version <= current->key_version))
                return CARD_STORE_INVALID_ARGUMENT;
            if (credential->credential_version == current->credential_version) {
                if (card_credential_encode(current, current_wire, sizeof(current_wire)) == 0U ||
                    card_credential_encode(credential, updated_wire, sizeof(updated_wire)) == 0U ||
                    memcmp(current_wire, updated_wire, sizeof(current_wire)) != 0)
                    return CARD_STORE_INVALID_ARGUMENT;
                return CARD_STORE_OK;
            }
            candidate[i] = *credential;
            return commit(store, candidate, count);
        }
    }
    if (count >= CARD_MAX_CREDENTIALS) return CARD_STORE_FULL;
    candidate[count++] = *credential;
    return commit(store, candidate, count);
}

card_store_result_t card_store_get(const card_store_t *store, uint32_t permission_id,
                                   card_credential_t *credential)
{
    uint8_t i;
    if (store == NULL || credential == NULL || permission_id == 0U)
        return CARD_STORE_INVALID_ARGUMENT;
    if (!store->initialized) return CARD_STORE_NOT_INITIALIZED;
    for (i = 0U; i < store->credential_count; ++i) {
        if (store->credentials[i].permission_id == permission_id) {
            *credential = store->credentials[i];
            return CARD_STORE_OK;
        }
    }
    return CARD_STORE_NOT_FOUND;
}

size_t card_store_list(const card_store_t *store, card_credential_t *out, size_t capacity)
{
    size_t count;
    if (store == NULL || !store->initialized) return 0U;
    count = store->credential_count;
    if (out != NULL && capacity != 0U) {
        size_t copy_count = count < capacity ? count : capacity;
        (void)memcpy(out, store->credentials, copy_count * sizeof(card_credential_t));
    }
    return count;
}

card_store_result_t card_store_set_state(card_store_t *store, uint32_t permission_id,
                                         card_credential_state_t state)
{
    card_credential_t credential;
    card_store_result_t result;
    if (state > CARD_CREDENTIAL_REVOKED) return CARD_STORE_INVALID_ARGUMENT;
    result = card_store_get(store, permission_id, &credential);
    if (result != CARD_STORE_OK) return result;
    if (credential.credential_version == UINT32_MAX) return CARD_STORE_INVALID_ARGUMENT;
    credential.state = state;
    credential.credential_version++;
    return card_store_upsert(store, &credential);
}

card_store_result_t card_store_consume_usage(card_store_t *store, uint32_t permission_id,
                                             uint32_t minimum_counter,
                                             uint32_t *consumed_counter)
{
    card_credential_t candidate[CARD_MAX_CREDENTIALS];
    uint32_t current;
    uint8_t i;
    if (store == NULL || permission_id == 0U || consumed_counter == NULL ||
        minimum_counter == UINT32_MAX)
        return CARD_STORE_INVALID_ARGUMENT;
    if (!store->initialized) return CARD_STORE_NOT_INITIALIZED;
    (void)memcpy(candidate, store->credentials,
                 (size_t)store->credential_count * sizeof(card_credential_t));
    for (i = 0U; i < store->credential_count; ++i) {
        if (candidate[i].permission_id != permission_id) continue;
        current = candidate[i].usage_count;
        if (current < minimum_counter) current = minimum_counter;
        if (current >= candidate[i].usage_limit || current == UINT32_MAX)
            return CARD_STORE_USAGE_EXHAUSTED;
        candidate[i].usage_count = current + 1U;
        {
            card_store_result_t result = commit(store, candidate, store->credential_count);
            if (result != CARD_STORE_OK) return result;
        }
        *consumed_counter = current + 1U;
        return CARD_STORE_OK;
    }
    return CARD_STORE_NOT_FOUND;
}
