#ifndef SLE_CARD_SERVICE_H
#define SLE_CARD_SERVICE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "ab_protocol.h"
#include "credential_store.h"

#define CARD_SERVICE_PROTOCOL_VERSION 1U
#define CARD_SERVICE_MAX_CHUNK_DATA 48U
#define CARD_SERVICE_RESULT_SIZE 18U
#define CARD_SERVICE_INFO_SIZE 16U
#define CARD_SERVICE_LIST_ITEM_SIZE 48U
#define CARD_SERVICE_RESULT_CACHE_SIZE 8U
#define CARD_CAP_PERSISTENT_STORE 0x01U
#define CARD_CAP_SERIAL_PROVISIONING 0x02U
#define CARD_CAP_ATOMIC_USAGE_COUNTER 0x04U

typedef enum {
    CARD_SERVICE_OK = 0,
    CARD_SERVICE_INVALID_MESSAGE = 1,
    CARD_SERVICE_UNSUPPORTED = 2,
    CARD_SERVICE_BUSY = 3,
    CARD_SERVICE_NO_TRANSACTION = 4,
    CARD_SERVICE_REQUEST_MISMATCH = 5,
    CARD_SERVICE_OFFSET_MISMATCH = 6,
    CARD_SERVICE_LENGTH_MISMATCH = 7,
    CARD_SERVICE_CRC_MISMATCH = 8,
    CARD_SERVICE_INVALID_CREDENTIAL = 9,
    CARD_SERVICE_NOT_FOUND = 10,
    CARD_SERVICE_STORE_FULL = 11,
    CARD_SERVICE_STORE_IO_ERROR = 12,
    CARD_SERVICE_STORE_VERIFY_ERROR = 13,
    CARD_SERVICE_SEND_FAILED = 14
} card_service_status_t;

typedef bool (*card_service_send_fn)(uint8_t message_type, uint8_t flags,
                                     const uint8_t *payload, uint16_t payload_length,
                                     void *user);

typedef struct {
    bool valid;
    bool fingerprint_valid;
    uint32_t request_id;
    uint32_t request_fingerprint;
    uint8_t command_type;
    uint8_t payload[CARD_SERVICE_RESULT_SIZE];
} card_service_result_cache_entry_t;

typedef struct {
    bool active;
    uint32_t request_id;
    uint32_t expected_crc32;
    uint16_t expected_length;
    uint16_t received_length;
    uint8_t data[CARD_CREDENTIAL_WIRE_SIZE];
} card_write_transaction_t;

typedef struct {
    card_store_t *store;
    card_service_send_fn send;
    void *user;
    uint32_t card_id;
    uint32_t firmware_version;
    uint8_t capability_flags;
    card_write_transaction_t transaction;
    card_service_result_cache_entry_t result_cache[CARD_SERVICE_RESULT_CACHE_SIZE];
    uint8_t result_cache_next;
    uint32_t commands_received;
    uint32_t malformed_commands;
    uint32_t duplicate_requests;
    uint32_t send_failures;
} card_service_t;

void card_service_init(card_service_t *service, card_store_t *store, uint32_t card_id,
                       uint32_t firmware_version, card_service_send_fn send, void *user);
void card_service_set_capabilities(card_service_t *service, uint8_t capability_flags);
card_service_status_t card_service_handle_command(card_service_t *service,
                                                  uint8_t message_type,
                                                  const uint8_t *payload,
                                                  uint16_t payload_length);
void card_service_abort_transaction(card_service_t *service);

#endif
