#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "card_service.h"
#include "credential_store.h"

#define MAX_RESPONSES 32U

typedef struct {
    uint8_t type;
    uint8_t flags;
    uint16_t length;
    uint8_t payload[AB_MAX_PAYLOAD];
} captured_response_t;

typedef struct {
    captured_response_t responses[MAX_RESPONSES];
    size_t count;
    bool fail_next;
} response_log_t;

typedef struct {
    uint8_t slots[CARD_STORE_SLOT_COUNT][CARD_STORE_SLOT_SIZE];
    bool present[CARD_STORE_SLOT_COUNT];
    bool fail_next_write;
    bool corrupt_next_write;
} memory_backend_t;

static bool memory_read(uint8_t slot, uint8_t *data, size_t length, void *user)
{
    memory_backend_t *memory = (memory_backend_t *)user;
    if (slot >= CARD_STORE_SLOT_COUNT || length != CARD_STORE_SLOT_SIZE || !memory->present[slot])
        return false;
    memcpy(data, memory->slots[slot], length);
    return true;
}

static bool memory_write(uint8_t slot, const uint8_t *data, size_t length, void *user)
{
    memory_backend_t *memory = (memory_backend_t *)user;
    if (slot >= CARD_STORE_SLOT_COUNT || length != CARD_STORE_SLOT_SIZE) return false;
    if (memory->fail_next_write) {
        memory->fail_next_write = false;
        return false;
    }
    memcpy(memory->slots[slot], data, length);
    memory->present[slot] = true;
    if (memory->corrupt_next_write) {
        memory->corrupt_next_write = false;
        memory->slots[slot][20] ^= 0x80U;
    }
    return true;
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

static uint32_t read_u32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static bool capture_response(uint8_t message_type, uint8_t flags,
                             const uint8_t *payload, uint16_t payload_length, void *user)
{
    response_log_t *log = (response_log_t *)user;
    captured_response_t *response;
    if (log->fail_next) {
        log->fail_next = false;
        return false;
    }
    if (log->count >= MAX_RESPONSES || payload_length > AB_MAX_PAYLOAD) return false;
    response = &log->responses[log->count++];
    memset(response, 0, sizeof(*response));
    response->type = message_type;
    response->flags = flags;
    response->length = payload_length;
    if (payload_length != 0U) memcpy(response->payload, payload, payload_length);
    return true;
}

static captured_response_t *last_response(response_log_t *log)
{
    assert(log->count != 0U);
    return &log->responses[log->count - 1U];
}

static uint8_t last_result_status(response_log_t *log)
{
    captured_response_t *response = last_response(log);
    assert(response->type == AB_MSG_CREDENTIAL_RESULT);
    assert(response->length == CARD_SERVICE_RESULT_SIZE);
    return response->payload[5];
}

static card_credential_t credential(uint32_t permission_id, uint8_t key_seed)
{
    card_credential_t value;
    size_t i;
    memset(&value, 0, sizeof(value));
    value.permission_id = permission_id;
    value.organization_id = 0x1001U;
    value.scope_type = CARD_SCOPE_CHECKPOINT;
    value.scope_id = 0x2001U;
    value.valid_from = 100U;
    value.valid_to = 10000U;
    value.policy_flags = 3U;
    value.usage_limit = 10U;
    value.credential_version = 1U;
    value.key_version = 1U;
    value.state = CARD_CREDENTIAL_ACTIVE;
    for (i = 0U; i < CARD_KEY_SIZE; ++i) value.key[i] = (uint8_t)(key_seed + i);
    return value;
}

static void test_store_update_and_reboot(void)
{
    memory_backend_t memory;
    card_store_backend_t backend;
    card_store_t store;
    card_store_t rebooted;
    card_credential_t first = credential(1U, 0x10U);
    card_credential_t second = credential(2U, 0x40U);
    card_credential_t readback;
    memset(&memory, 0, sizeof(memory));
    backend.read_slot = memory_read;
    backend.write_slot = memory_write;
    backend.user = &memory;

    assert(card_store_init(&store, &backend) == CARD_STORE_OK);
    assert(card_store_list(&store, NULL, 0U) == 0U);
    assert(card_store_upsert(&store, &first) == CARD_STORE_OK);
    assert(store.generation == 1U);
    assert(card_store_upsert(&store, &second) == CARD_STORE_OK);
    assert(store.generation == 2U);
    assert(card_store_list(&store, NULL, 0U) == 2U);

    first.policy_flags = 7U;
    first.credential_version = 2U;
    assert(card_store_upsert(&store, &first) == CARD_STORE_OK);
    {
        card_credential_t rollback = first;
        uint32_t generation = store.generation;
        assert(card_store_upsert(&store, &first) == CARD_STORE_OK);
        assert(store.generation == generation);
        rollback.credential_version = 1U;
        assert(card_store_upsert(&store, &rollback) == CARD_STORE_INVALID_ARGUMENT);
        rollback = first;
        rollback.key[0] ^= 1U;
        assert(card_store_upsert(&store, &rollback) == CARD_STORE_INVALID_ARGUMENT);
        rollback = first;
        rollback.policy_flags ^= 1U;
        assert(card_store_upsert(&store, &rollback) == CARD_STORE_INVALID_ARGUMENT);
        assert(store.generation == generation);
    }
    assert(card_store_get(&store, 1U, &readback) == CARD_STORE_OK);
    assert(readback.policy_flags == 7U);
    assert(readback.credential_version == 2U);

    assert(card_store_init(&rebooted, &backend) == CARD_STORE_OK);
    assert(rebooted.generation == 3U);
    assert(card_store_list(&rebooted, NULL, 0U) == 2U);
    assert(card_store_get(&rebooted, 2U, &readback) == CARD_STORE_OK);
    assert(memcmp(readback.key, second.key, CARD_KEY_SIZE) == 0);
}

static void test_atomic_failure_recovery(void)
{
    memory_backend_t memory;
    card_store_backend_t backend;
    card_store_t store;
    card_store_t rebooted;
    card_credential_t first = credential(1U, 0x10U);
    card_credential_t second = credential(2U, 0x40U);
    memset(&memory, 0, sizeof(memory));
    backend.read_slot = memory_read;
    backend.write_slot = memory_write;
    backend.user = &memory;
    assert(card_store_init(&store, &backend) == CARD_STORE_OK);
    assert(card_store_upsert(&store, &first) == CARD_STORE_OK);

    memory.fail_next_write = true;
    assert(card_store_upsert(&store, &second) == CARD_STORE_IO_ERROR);
    assert(store.generation == 1U);
    assert(card_store_list(&store, NULL, 0U) == 1U);
    assert(card_store_init(&rebooted, &backend) == CARD_STORE_OK);
    assert(card_store_list(&rebooted, NULL, 0U) == 1U);

    memory.corrupt_next_write = true;
    assert(card_store_upsert(&rebooted, &second) == CARD_STORE_VERIFY_ERROR);
    assert(card_store_init(&store, &backend) == CARD_STORE_OK);
    assert(store.generation == 1U);
    assert(card_store_list(&store, NULL, 0U) == 1U);
}

static void test_usage_consumption_and_recovery(void)
{
    memory_backend_t memory;
    card_store_backend_t backend;
    card_store_t store;
    card_store_t rebooted;
    card_credential_t value = credential(17U, 0x31U);
    card_credential_t readback;
    uint32_t counter = 0U;
    memset(&memory, 0, sizeof(memory));
    backend.read_slot = memory_read;
    backend.write_slot = memory_write;
    backend.user = &memory;
    assert(card_store_init(&store, &backend) == CARD_STORE_OK);
    assert(card_store_upsert(&store, &value) == CARD_STORE_OK);
    assert(card_store_consume_usage(&store, value.permission_id, 5U, &counter) ==
           CARD_STORE_OK);
    assert(counter == 6U);
    assert(card_store_init(&rebooted, &backend) == CARD_STORE_OK);
    assert(card_store_get(&rebooted, value.permission_id, &readback) == CARD_STORE_OK);
    assert(readback.usage_count == 6U);

    memory.fail_next_write = true;
    assert(card_store_consume_usage(&rebooted, value.permission_id, 6U, &counter) ==
           CARD_STORE_IO_ERROR);
    assert(card_store_get(&rebooted, value.permission_id, &readback) == CARD_STORE_OK);
    assert(readback.usage_count == 6U);

    assert(card_store_consume_usage(&rebooted, value.permission_id, 9U, &counter) ==
           CARD_STORE_OK);
    assert(counter == 10U);
    assert(card_store_consume_usage(&rebooted, value.permission_id, 10U, &counter) ==
           CARD_STORE_USAGE_EXHAUSTED);
}

static void test_state_and_capacity(void)
{
    memory_backend_t memory;
    card_store_backend_t backend;
    card_store_t store;
    card_credential_t value;
    uint32_t i;
    memset(&memory, 0, sizeof(memory));
    backend.read_slot = memory_read;
    backend.write_slot = memory_write;
    backend.user = &memory;
    assert(card_store_init(&store, &backend) == CARD_STORE_OK);
    for (i = 1U; i <= CARD_MAX_CREDENTIALS; ++i) {
        value = credential(i, (uint8_t)i);
        assert(card_store_upsert(&store, &value) == CARD_STORE_OK);
    }
    value = credential(99U, 0x70U);
    assert(card_store_upsert(&store, &value) == CARD_STORE_FULL);
    assert(card_store_set_state(&store, 3U, CARD_CREDENTIAL_REVOKED) == CARD_STORE_OK);
    assert(card_store_get(&store, 3U, &value) == CARD_STORE_OK);
    assert(value.state == CARD_CREDENTIAL_REVOKED);
    assert(value.credential_version == 2U);
}

static void init_service(memory_backend_t *memory, card_store_backend_t *backend,
                         card_store_t *store, card_service_t *service,
                         response_log_t *log)
{
    memset(memory, 0, sizeof(*memory));
    memset(log, 0, sizeof(*log));
    backend->read_slot = memory_read;
    backend->write_slot = memory_write;
    backend->user = memory;
    assert(card_store_init(store, backend) == CARD_STORE_OK);
    card_service_init(service, store, 0xCA4D0001U, 0x00010000U,
                      capture_response, log);
}

static void send_begin(card_service_t *service, const card_credential_t *value,
                       uint32_t request_id, uint32_t crc_delta)
{
    uint8_t encoded[CARD_CREDENTIAL_WIRE_SIZE];
    uint8_t begin[10];
    assert(card_credential_encode(value, encoded, sizeof(encoded)) == sizeof(encoded));
    write_u32(&begin[0], request_id);
    write_u16(&begin[4], CARD_CREDENTIAL_WIRE_SIZE);
    write_u32(&begin[6], card_store_crc32(encoded, sizeof(encoded)) ^ crc_delta);
    assert(card_service_handle_command(service, AB_MSG_CREDENTIAL_BEGIN,
                                       begin, sizeof(begin)) == CARD_SERVICE_OK);
}

static void send_chunk(card_service_t *service, const uint8_t *encoded,
                       uint32_t request_id, uint16_t offset, uint8_t length)
{
    uint8_t chunk[7U + CARD_SERVICE_MAX_CHUNK_DATA];
    write_u32(&chunk[0], request_id);
    write_u16(&chunk[4], offset);
    chunk[6] = length;
    memcpy(&chunk[7], &encoded[offset], length);
    assert(card_service_handle_command(service, AB_MSG_CREDENTIAL_CHUNK,
                                       chunk, (uint16_t)(7U + length)) == CARD_SERVICE_OK);
}

static void send_complete_credential(card_service_t *service,
                                     const card_credential_t *value,
                                     uint32_t request_id)
{
    uint8_t encoded[CARD_CREDENTIAL_WIRE_SIZE];
    uint8_t commit[4];
    assert(card_credential_encode(value, encoded, sizeof(encoded)) == sizeof(encoded));
    send_begin(service, value, request_id, 0U);
    send_chunk(service, encoded, request_id, 0U, 40U);
    send_chunk(service, encoded, request_id, 40U,
               (uint8_t)(CARD_CREDENTIAL_WIRE_SIZE - 40U));
    write_u32(commit, request_id);
    assert(card_service_handle_command(service, AB_MSG_CREDENTIAL_COMMIT,
                                       commit, sizeof(commit)) == CARD_SERVICE_OK);
}

static void test_card_service_fragmented_write_and_idempotency(void)
{
    memory_backend_t memory;
    card_store_backend_t backend;
    card_store_t store;
    card_service_t service;
    response_log_t log;
    card_credential_t value = credential(11U, 0x21U);
    card_credential_t conflicting = credential(12U, 0x22U);
    card_credential_t readback;
    uint8_t encoded[CARD_CREDENTIAL_WIRE_SIZE];
    uint8_t commit[4];
    uint32_t generation;
    init_service(&memory, &backend, &store, &service, &log);
    assert(card_credential_encode(&value, encoded, sizeof(encoded)) == sizeof(encoded));
    send_begin(&service, &value, 1001U, 0U);
    send_chunk(&service, encoded, 1001U, 0U, 40U);
    send_chunk(&service, encoded, 1001U, 0U, 40U);
    assert(service.duplicate_requests == 1U);
    send_chunk(&service, encoded, 1001U, 40U,
               (uint8_t)(CARD_CREDENTIAL_WIRE_SIZE - 40U));
    write_u32(commit, 1001U);
    assert(card_service_handle_command(&service, AB_MSG_CREDENTIAL_COMMIT,
                                       commit, sizeof(commit)) == CARD_SERVICE_OK);
    assert(last_result_status(&log) == CARD_SERVICE_OK);
    assert(card_store_get(&store, value.permission_id, &readback) == CARD_STORE_OK);
    assert(memcmp(readback.key, value.key, CARD_KEY_SIZE) == 0);
    generation = store.generation;
    assert(card_service_handle_command(&service, AB_MSG_CREDENTIAL_COMMIT,
                                       commit, sizeof(commit)) == CARD_SERVICE_OK);
    assert(store.generation == generation);
    assert(service.duplicate_requests == 2U);
    assert(last_result_status(&log) == CARD_SERVICE_OK);
    send_begin(&service, &conflicting, 1001U, 0U);
    assert(last_result_status(&log) == CARD_SERVICE_REQUEST_MISMATCH);
    assert(!service.transaction.active);
    assert(store.generation == generation);
}

static void test_card_service_crc_busy_and_state_idempotency(void)
{
    memory_backend_t memory;
    card_store_backend_t backend;
    card_store_t store;
    card_service_t service;
    response_log_t log;
    card_credential_t first = credential(21U, 0x31U);
    card_credential_t second = credential(22U, 0x41U);
    card_credential_t readback;
    uint8_t encoded[CARD_CREDENTIAL_WIRE_SIZE];
    uint8_t begin[10];
    uint8_t commit[4];
    uint8_t state[9];
    uint32_t generation;
    init_service(&memory, &backend, &store, &service, &log);
    send_begin(&service, &first, 2001U, 0U);
    assert(card_credential_encode(&second, encoded, sizeof(encoded)) == sizeof(encoded));
    write_u32(&begin[0], 2002U);
    write_u16(&begin[4], CARD_CREDENTIAL_WIRE_SIZE);
    write_u32(&begin[6], card_store_crc32(encoded, sizeof(encoded)));
    assert(card_service_handle_command(&service, AB_MSG_CREDENTIAL_BEGIN,
                                       begin, sizeof(begin)) == CARD_SERVICE_OK);
    assert(last_result_status(&log) == CARD_SERVICE_BUSY);
    card_service_abort_transaction(&service);

    send_begin(&service, &first, 2003U, 1U);
    assert(card_credential_encode(&first, encoded, sizeof(encoded)) == sizeof(encoded));
    send_chunk(&service, encoded, 2003U, 0U, 40U);
    send_chunk(&service, encoded, 2003U, 40U,
               (uint8_t)(CARD_CREDENTIAL_WIRE_SIZE - 40U));
    write_u32(commit, 2003U);
    assert(card_service_handle_command(&service, AB_MSG_CREDENTIAL_COMMIT,
                                       commit, sizeof(commit)) == CARD_SERVICE_OK);
    assert(last_result_status(&log) == CARD_SERVICE_CRC_MISMATCH);
    assert(card_store_list(&store, NULL, 0U) == 0U);

    send_complete_credential(&service, &first, 2004U);
    assert(last_result_status(&log) == CARD_SERVICE_OK);
    generation = store.generation;
    write_u32(&state[0], 2004U);
    write_u32(&state[4], first.permission_id);
    state[8] = CARD_CREDENTIAL_FROZEN;
    assert(card_service_handle_command(&service, AB_MSG_CARD_STATE_SET,
                                       state, sizeof(state)) == CARD_SERVICE_OK);
    assert(last_result_status(&log) == CARD_SERVICE_REQUEST_MISMATCH);
    assert(store.generation == generation);
    assert(card_store_get(&store, first.permission_id, &readback) == CARD_STORE_OK);
    assert(readback.state == CARD_CREDENTIAL_ACTIVE);
    write_u32(&state[0], 2005U);
    write_u32(&state[4], first.permission_id);
    state[8] = CARD_CREDENTIAL_FROZEN;
    assert(card_service_handle_command(&service, AB_MSG_CARD_STATE_SET,
                                       state, sizeof(state)) == CARD_SERVICE_OK);
    assert(last_result_status(&log) == CARD_SERVICE_OK);
    assert(card_store_get(&store, first.permission_id, &readback) == CARD_STORE_OK);
    assert(readback.state == CARD_CREDENTIAL_FROZEN);
    assert(readback.credential_version == 2U);
    generation = store.generation;
    assert(card_service_handle_command(&service, AB_MSG_CARD_STATE_SET,
                                       state, sizeof(state)) == CARD_SERVICE_OK);
    assert(store.generation == generation);
    assert(card_store_get(&store, first.permission_id, &readback) == CARD_STORE_OK);
    assert(readback.credential_version == 2U);
    state[8] = CARD_CREDENTIAL_LOST;
    assert(card_service_handle_command(&service, AB_MSG_CARD_STATE_SET,
                                       state, sizeof(state)) == CARD_SERVICE_OK);
    assert(last_result_status(&log) == CARD_SERVICE_REQUEST_MISMATCH);
    assert(card_store_get(&store, first.permission_id, &readback) == CARD_STORE_OK);
    assert(readback.state == CARD_CREDENTIAL_FROZEN);
    assert(readback.credential_version == 2U);
}

static void test_card_service_info_list_and_send_failure(void)
{
    memory_backend_t memory;
    card_store_backend_t backend;
    card_store_t store;
    card_service_t service;
    response_log_t log;
    card_credential_t value = credential(31U, 0x51U);
    captured_response_t *response;
    uint8_t request[4];
    init_service(&memory, &backend, &store, &service, &log);
    card_service_set_capabilities(&service, CARD_CAP_ATOMIC_USAGE_COUNTER);
    send_complete_credential(&service, &value, 3001U);
    assert(card_service_handle_command(&service, AB_MSG_CARD_INFO, NULL, 0U) ==
           CARD_SERVICE_OK);
    response = last_response(&log);
    assert(response->type == AB_MSG_CARD_INFO);
    assert(response->length == CARD_SERVICE_INFO_SIZE);
    assert(response->payload[0] == CARD_SERVICE_PROTOCOL_VERSION);
    assert(response->payload[2] == 1U);
    assert(response->payload[3] == CARD_CAP_ATOMIC_USAGE_COUNTER);
    assert(read_u32(&response->payload[4]) == 0xCA4D0001U);

    write_u32(request, 3002U);
    assert(card_service_handle_command(&service, AB_MSG_CREDENTIAL_LIST,
                                       request, sizeof(request)) == CARD_SERVICE_OK);
    assert(log.responses[log.count - 2U].type == AB_MSG_CREDENTIAL_LIST);
    assert(log.responses[log.count - 2U].length == CARD_SERVICE_LIST_ITEM_SIZE);
    assert(read_u32(&log.responses[log.count - 2U].payload[6]) == value.permission_id);
    assert(last_result_status(&log) == CARD_SERVICE_OK);

    log.fail_next = true;
    assert(card_service_handle_command(&service, AB_MSG_CARD_INFO, NULL, 0U) ==
           CARD_SERVICE_SEND_FAILED);
    assert(service.send_failures == 1U);
}

int main(void)
{
    test_store_update_and_reboot();
    test_atomic_failure_recovery();
    test_usage_consumption_and_recovery();
    test_state_and_capacity();
    test_card_service_fragmented_write_and_idempotency();
    test_card_service_crc_busy_and_state_idempotency();
    test_card_service_info_list_and_send_failure();
    puts("All WS63 Card credential store and service tests passed.");
    return 0;
}
