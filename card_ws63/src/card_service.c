#include "card_service.h"

#include <string.h>

static uint16_t read_u16(const uint8_t *p)
{
    return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));
}

static uint32_t read_u32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void write_u32(uint8_t *p, uint32_t value)
{
    p[0] = (uint8_t)value;
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)(value >> 16);
    p[3] = (uint8_t)(value >> 24);
}

static card_service_status_t send_payload(card_service_t *service, uint8_t message_type,
                                          const uint8_t *payload, uint16_t payload_length)
{
    if (service->send == NULL ||
        !service->send(message_type, AB_FLAG_RESPONSE, payload, payload_length, service->user)) {
        service->send_failures++;
        return CARD_SERVICE_SEND_FAILED;
    }
    return CARD_SERVICE_OK;
}

static card_service_status_t map_store_result(card_store_result_t result)
{
    switch (result) {
        case CARD_STORE_OK: return CARD_SERVICE_OK;
        case CARD_STORE_NOT_FOUND: return CARD_SERVICE_NOT_FOUND;
        case CARD_STORE_FULL: return CARD_SERVICE_STORE_FULL;
        case CARD_STORE_IO_ERROR: return CARD_SERVICE_STORE_IO_ERROR;
        case CARD_STORE_VERIFY_ERROR: return CARD_SERVICE_STORE_VERIFY_ERROR;
        default: return CARD_SERVICE_INVALID_CREDENTIAL;
    }
}

static void encode_result(uint8_t *payload, uint32_t request_id, uint8_t command_type,
                          card_service_status_t status, uint32_t permission_id,
                          uint32_t credential_version, uint32_t generation)
{
    write_u32(&payload[0], request_id);
    payload[4] = command_type;
    payload[5] = (uint8_t)status;
    write_u32(&payload[6], permission_id);
    write_u32(&payload[10], credential_version);
    write_u32(&payload[14], generation);
}

static const card_service_result_cache_entry_t *find_cached_result(
    const card_service_t *service, uint32_t request_id)
{
    uint8_t i;
    for (i = 0U; i < CARD_SERVICE_RESULT_CACHE_SIZE; ++i) {
        if (service->result_cache[i].valid &&
            service->result_cache[i].request_id == request_id) return &service->result_cache[i];
    }
    return NULL;
}

static bool cache_type_matches(uint8_t cached_type, uint8_t requested_type)
{
    bool credential_transaction = requested_type == AB_MSG_CREDENTIAL_BEGIN ||
                                  requested_type == AB_MSG_CREDENTIAL_CHUNK ||
                                  requested_type == AB_MSG_CREDENTIAL_COMMIT;
    return cached_type == requested_type ||
           (credential_transaction && cached_type == AB_MSG_CREDENTIAL_COMMIT);
}

static card_service_status_t replay_cached_result(card_service_t *service,
                                                   uint32_t request_id,
                                                   uint8_t command_type,
                                                   bool fingerprint_valid,
                                                   uint32_t request_fingerprint)
{
    const card_service_result_cache_entry_t *cached = find_cached_result(service, request_id);
    uint8_t payload[CARD_SERVICE_RESULT_SIZE];
    if (cached == NULL) return CARD_SERVICE_NOT_FOUND;
    if (!cache_type_matches(cached->command_type, command_type)) {
        encode_result(payload, request_id, command_type, CARD_SERVICE_REQUEST_MISMATCH,
                      0U, 0U, service->store->generation);
        return send_payload(service, AB_MSG_CREDENTIAL_RESULT, payload, sizeof(payload));
    }
    if (fingerprint_valid && cached->fingerprint_valid &&
        cached->request_fingerprint != request_fingerprint) {
        encode_result(payload, request_id, command_type, CARD_SERVICE_REQUEST_MISMATCH,
                      0U, 0U, service->store->generation);
        return send_payload(service, AB_MSG_CREDENTIAL_RESULT, payload, sizeof(payload));
    }
    service->duplicate_requests++;
    return send_payload(service, AB_MSG_CREDENTIAL_RESULT, cached->payload,
                        CARD_SERVICE_RESULT_SIZE);
}

static card_service_status_t send_result(card_service_t *service, uint32_t request_id,
                                         uint8_t command_type, card_service_status_t status,
                                         uint32_t permission_id, uint32_t credential_version,
                                         bool cache, bool fingerprint_valid,
                                         uint32_t request_fingerprint)
{
    uint8_t payload[CARD_SERVICE_RESULT_SIZE];
    encode_result(payload, request_id, command_type, status, permission_id,
                  credential_version, service->store->generation);
    if (cache) {
        card_service_result_cache_entry_t *entry =
            &service->result_cache[service->result_cache_next];
        entry->valid = true;
        entry->fingerprint_valid = fingerprint_valid;
        entry->request_id = request_id;
        entry->request_fingerprint = request_fingerprint;
        entry->command_type = command_type;
        (void)memcpy(entry->payload, payload, sizeof(payload));
        service->result_cache_next =
            (uint8_t)((service->result_cache_next + 1U) % CARD_SERVICE_RESULT_CACHE_SIZE);
    }
    return send_payload(service, AB_MSG_CREDENTIAL_RESULT, payload, sizeof(payload));
}

static card_service_status_t handle_info(card_service_t *service,
                                         const uint8_t *payload, uint16_t payload_length)
{
    uint8_t response[CARD_SERVICE_INFO_SIZE] = { 0U };
    (void)payload;
    if (payload_length != 0U) return CARD_SERVICE_INVALID_MESSAGE;
    response[0] = CARD_SERVICE_PROTOCOL_VERSION;
    response[1] = CARD_MAX_CREDENTIALS;
    response[2] = service->store->credential_count;
    response[3] = service->capability_flags;
    write_u32(&response[4], service->card_id);
    write_u32(&response[8], service->firmware_version);
    write_u32(&response[12], service->store->generation);
    return send_payload(service, AB_MSG_CARD_INFO, response, sizeof(response));
}

static card_service_status_t handle_begin(card_service_t *service,
                                          const uint8_t *payload, uint16_t payload_length)
{
    uint32_t request_id;
    uint16_t expected_length;
    uint32_t expected_crc32;
    card_service_status_t replay;
    if (payload == NULL || payload_length != 10U) return CARD_SERVICE_INVALID_MESSAGE;
    request_id = read_u32(&payload[0]);
    expected_length = read_u16(&payload[4]);
    expected_crc32 = read_u32(&payload[6]);
    if (request_id == 0U) return CARD_SERVICE_INVALID_MESSAGE;
    if (expected_length != CARD_CREDENTIAL_WIRE_SIZE)
        return send_result(service, request_id, AB_MSG_CREDENTIAL_BEGIN,
                           CARD_SERVICE_LENGTH_MISMATCH, 0U, 0U, false, false, 0U);
    replay = replay_cached_result(service, request_id, AB_MSG_CREDENTIAL_BEGIN,
                                  true, expected_crc32);
    if (replay != CARD_SERVICE_NOT_FOUND) return replay;
    if (service->transaction.active) {
        if (service->transaction.request_id != request_id)
            return send_result(service, request_id, AB_MSG_CREDENTIAL_BEGIN,
                               CARD_SERVICE_BUSY, 0U, 0U, false, false, 0U);
        if (service->transaction.expected_length != expected_length ||
            service->transaction.expected_crc32 != expected_crc32)
            return send_result(service, request_id, AB_MSG_CREDENTIAL_BEGIN,
                               CARD_SERVICE_REQUEST_MISMATCH, 0U, 0U, false, false, 0U);
        return send_result(service, request_id, AB_MSG_CREDENTIAL_BEGIN, CARD_SERVICE_OK,
                           0U, 0U, false, false, 0U);
    }
    (void)memset(&service->transaction, 0, sizeof(service->transaction));
    service->transaction.active = true;
    service->transaction.request_id = request_id;
    service->transaction.expected_length = expected_length;
    service->transaction.expected_crc32 = expected_crc32;
    return send_result(service, request_id, AB_MSG_CREDENTIAL_BEGIN, CARD_SERVICE_OK,
                       0U, 0U, false, false, 0U);
}

static card_service_status_t handle_chunk(card_service_t *service,
                                          const uint8_t *payload, uint16_t payload_length)
{
    card_write_transaction_t *transaction = &service->transaction;
    uint32_t request_id;
    uint16_t offset;
    uint8_t chunk_length;
    if (payload == NULL || payload_length < 8U) return CARD_SERVICE_INVALID_MESSAGE;
    request_id = read_u32(&payload[0]);
    offset = read_u16(&payload[4]);
    chunk_length = payload[6];
    if (request_id == 0U || chunk_length == 0U || chunk_length > CARD_SERVICE_MAX_CHUNK_DATA ||
        payload_length != (uint16_t)(7U + chunk_length)) return CARD_SERVICE_INVALID_MESSAGE;
    if (!transaction->active) {
        card_service_status_t replay = replay_cached_result(
            service, request_id, AB_MSG_CREDENTIAL_CHUNK, false, 0U);
        return replay == CARD_SERVICE_NOT_FOUND ?
            send_result(service, request_id, AB_MSG_CREDENTIAL_CHUNK,
                        CARD_SERVICE_NO_TRANSACTION, 0U, 0U, false, false, 0U) : replay;
    }
    if (transaction->request_id != request_id)
        return send_result(service, request_id, AB_MSG_CREDENTIAL_CHUNK,
                           CARD_SERVICE_REQUEST_MISMATCH, 0U, 0U, false, false, 0U);
    if ((uint32_t)offset + chunk_length > transaction->expected_length)
        return send_result(service, request_id, AB_MSG_CREDENTIAL_CHUNK,
                           CARD_SERVICE_LENGTH_MISMATCH, 0U, 0U, false, false, 0U);
    if (offset < transaction->received_length) {
        if ((uint32_t)offset + chunk_length <= transaction->received_length &&
            memcmp(&transaction->data[offset], &payload[7], chunk_length) == 0) {
            service->duplicate_requests++;
            return send_result(service, request_id, AB_MSG_CREDENTIAL_CHUNK, CARD_SERVICE_OK,
                               0U, 0U, false, false, 0U);
        }
        return send_result(service, request_id, AB_MSG_CREDENTIAL_CHUNK,
                           CARD_SERVICE_OFFSET_MISMATCH, 0U, 0U, false, false, 0U);
    }
    if (offset != transaction->received_length)
        return send_result(service, request_id, AB_MSG_CREDENTIAL_CHUNK,
                           CARD_SERVICE_OFFSET_MISMATCH, 0U, 0U, false, false, 0U);
    (void)memcpy(&transaction->data[offset], &payload[7], chunk_length);
    transaction->received_length = (uint16_t)(transaction->received_length + chunk_length);
    return send_result(service, request_id, AB_MSG_CREDENTIAL_CHUNK, CARD_SERVICE_OK,
                       0U, 0U, false, false, 0U);
}

static card_service_status_t handle_commit(card_service_t *service,
                                           const uint8_t *payload, uint16_t payload_length)
{
    card_write_transaction_t *transaction = &service->transaction;
    card_credential_t credential;
    card_store_result_t store_result;
    card_service_status_t status;
    uint32_t request_id;
    uint32_t permission_id = 0U;
    uint32_t credential_version = 0U;
    card_service_status_t replay;
    if (payload == NULL || payload_length != 4U) return CARD_SERVICE_INVALID_MESSAGE;
    request_id = read_u32(payload);
    replay = replay_cached_result(service, request_id, AB_MSG_CREDENTIAL_COMMIT,
                                  false, 0U);
    if (replay != CARD_SERVICE_NOT_FOUND) return replay;
    if (!transaction->active)
        return send_result(service, request_id, AB_MSG_CREDENTIAL_COMMIT,
                           CARD_SERVICE_NO_TRANSACTION, 0U, 0U, false, false, 0U);
    if (transaction->request_id != request_id)
        return send_result(service, request_id, AB_MSG_CREDENTIAL_COMMIT,
                           CARD_SERVICE_REQUEST_MISMATCH, 0U, 0U, false, false, 0U);
    if (transaction->received_length != transaction->expected_length) {
        status = CARD_SERVICE_LENGTH_MISMATCH;
    } else if (card_store_crc32(transaction->data, transaction->expected_length) !=
               transaction->expected_crc32) {
        status = CARD_SERVICE_CRC_MISMATCH;
    } else if (!card_credential_decode(transaction->data, transaction->expected_length,
                                       &credential)) {
        status = CARD_SERVICE_INVALID_CREDENTIAL;
    } else {
        permission_id = credential.permission_id;
        credential_version = credential.credential_version;
        store_result = card_store_upsert(service->store, &credential);
        status = map_store_result(store_result);
    }
    {
        uint32_t request_fingerprint = transaction->expected_crc32;
        (void)memset(transaction, 0, sizeof(*transaction));
        return send_result(service, request_id, AB_MSG_CREDENTIAL_COMMIT, status,
                           permission_id, credential_version, true, true,
                           request_fingerprint);
    }
}

static card_service_status_t handle_list(card_service_t *service,
                                         const uint8_t *payload, uint16_t payload_length)
{
    uint8_t response[CARD_SERVICE_LIST_ITEM_SIZE];
    uint32_t request_id;
    uint8_t i;
    if (payload == NULL || payload_length != 4U) return CARD_SERVICE_INVALID_MESSAGE;
    request_id = read_u32(payload);
    if (request_id == 0U) return CARD_SERVICE_INVALID_MESSAGE;
    for (i = 0U; i < service->store->credential_count; ++i) {
        const card_credential_t *credential = &service->store->credentials[i];
        (void)memset(response, 0, sizeof(response));
        write_u32(&response[0], request_id);
        response[4] = i;
        response[5] = service->store->credential_count;
        write_u32(&response[6], credential->permission_id);
        write_u32(&response[10], credential->organization_id);
        response[14] = (uint8_t)credential->scope_type;
        write_u32(&response[15], credential->scope_id);
        write_u32(&response[19], credential->valid_from);
        write_u32(&response[23], credential->valid_to);
        write_u32(&response[27], credential->policy_flags);
        write_u32(&response[31], credential->usage_limit);
        write_u32(&response[35], credential->usage_count);
        write_u32(&response[39], credential->credential_version);
        write_u32(&response[43], credential->key_version);
        response[47] = (uint8_t)credential->state;
        if (send_payload(service, AB_MSG_CREDENTIAL_LIST, response, sizeof(response)) !=
            CARD_SERVICE_OK) return CARD_SERVICE_SEND_FAILED;
    }
    return send_result(service, request_id, AB_MSG_CREDENTIAL_LIST, CARD_SERVICE_OK,
                       0U, 0U, false, false, 0U);
}

static card_service_status_t handle_state_set(card_service_t *service,
                                              const uint8_t *payload,
                                              uint16_t payload_length)
{
    card_credential_t credential;
    card_store_result_t store_result;
    card_service_status_t status;
    card_service_status_t replay;
    uint32_t request_id;
    uint32_t permission_id;
    card_credential_state_t state;
    uint32_t credential_version = 0U;
    if (payload == NULL || payload_length != 9U) return CARD_SERVICE_INVALID_MESSAGE;
    request_id = read_u32(&payload[0]);
    permission_id = read_u32(&payload[4]);
    state = (card_credential_state_t)payload[8];
    if (request_id == 0U) return CARD_SERVICE_INVALID_MESSAGE;
    if (permission_id == 0U || state > CARD_CREDENTIAL_REVOKED)
        return send_result(service, request_id, AB_MSG_CARD_STATE_SET,
                           CARD_SERVICE_INVALID_MESSAGE, permission_id, 0U,
                           false, false, 0U);
    replay = replay_cached_result(service, request_id, AB_MSG_CARD_STATE_SET,
                                  true, card_store_crc32(&payload[4], 5U));
    if (replay != CARD_SERVICE_NOT_FOUND) return replay;
    store_result = card_store_set_state(service->store, permission_id, state);
    status = map_store_result(store_result);
    if (store_result == CARD_STORE_OK &&
        card_store_get(service->store, permission_id, &credential) == CARD_STORE_OK)
        credential_version = credential.credential_version;
    return send_result(service, request_id, AB_MSG_CARD_STATE_SET, status,
                       permission_id, credential_version, true, true,
                       card_store_crc32(&payload[4], 5U));
}

void card_service_init(card_service_t *service, card_store_t *store, uint32_t card_id,
                       uint32_t firmware_version, card_service_send_fn send, void *user)
{
    if (service == NULL) return;
    (void)memset(service, 0, sizeof(*service));
    service->store = store;
    service->card_id = card_id;
    service->firmware_version = firmware_version;
    service->send = send;
    service->user = user;
}

void card_service_set_capabilities(card_service_t *service, uint8_t capability_flags)
{
    if (service == NULL) return;
    service->capability_flags = capability_flags;
}

void card_service_abort_transaction(card_service_t *service)
{
    if (service == NULL) return;
    (void)memset(&service->transaction, 0, sizeof(service->transaction));
}

card_service_status_t card_service_handle_command(card_service_t *service,
                                                  uint8_t message_type,
                                                  const uint8_t *payload,
                                                  uint16_t payload_length)
{
    card_service_status_t status;
    if (service == NULL || service->store == NULL || !service->store->initialized)
        return CARD_SERVICE_INVALID_MESSAGE;
    service->commands_received++;
    switch (message_type) {
        case AB_MSG_CARD_INFO:
            status = handle_info(service, payload, payload_length);
            break;
        case AB_MSG_CREDENTIAL_BEGIN:
            status = handle_begin(service, payload, payload_length);
            break;
        case AB_MSG_CREDENTIAL_CHUNK:
            status = handle_chunk(service, payload, payload_length);
            break;
        case AB_MSG_CREDENTIAL_COMMIT:
            status = handle_commit(service, payload, payload_length);
            break;
        case AB_MSG_CREDENTIAL_LIST:
            status = handle_list(service, payload, payload_length);
            break;
        case AB_MSG_CARD_STATE_SET:
            status = handle_state_set(service, payload, payload_length);
            break;
        default:
            status = CARD_SERVICE_UNSUPPORTED;
            break;
    }
    if (status == CARD_SERVICE_INVALID_MESSAGE || status == CARD_SERVICE_UNSUPPORTED)
        service->malformed_commands++;
    return status;
}
