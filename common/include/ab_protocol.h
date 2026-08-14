#ifndef SLE_AB_PROTOCOL_H
#define SLE_AB_PROTOCOL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define AB_PROTOCOL_VERSION 2U
#define AB_MAX_PAYLOAD 64U
#define AB_FRAME_HEADER_SIZE 20U
#define AB_FRAME_OVERHEAD 22U
#define AB_MAX_FRAME (AB_MAX_PAYLOAD + AB_FRAME_OVERHEAD)

#define AB_FLAG_ACK_REQUIRED 0x01U
#define AB_FLAG_RESPONSE 0x02U
#define AB_FLAG_RETRY 0x04U

typedef enum {
    AB_ROLE_UNKNOWN = 0,
    AB_ROLE_CARD = 1,
    AB_ROLE_DETECTOR_A = 2,
    AB_ROLE_DETECTOR_B = 3,
    AB_ROLE_HOST = 4
} ab_source_role_t;

typedef enum {
    AB_MSG_PASSAGE_EVENT = 0x10,
    AB_MSG_DECISION = 0x20,
    AB_MSG_HEARTBEAT = 0x30,
    AB_MSG_CARD_INFO = 0x40,
    AB_MSG_CREDENTIAL_BEGIN = 0x41,
    AB_MSG_CREDENTIAL_CHUNK = 0x42,
    AB_MSG_CREDENTIAL_COMMIT = 0x43,
    AB_MSG_CREDENTIAL_RESULT = 0x44,
    AB_MSG_CREDENTIAL_LIST = 0x45,
    AB_MSG_CARD_STATE_SET = 0x46,
    AB_MSG_AUTH_START = 0x50,
    AB_MSG_AUTH_CHALLENGE = 0x51,
    AB_MSG_AUTH_RESPONSE = 0x52,
    AB_MSG_AUTH_RESULT = 0x53,
    AB_MSG_POLICY_SYNC = 0x60,
    AB_MSG_POLICY_RESULT = 0x61,
    AB_MSG_EVENT_REPORT = 0x62,
    AB_MSG_ALERT_REPORT = 0x63,
    AB_MSG_CONFIRM_REQUEST = 0x64,
    AB_MSG_CONFIRM_RESULT = 0x65,
    AB_MSG_COMMAND_RESULT = 0x66,
    AB_MSG_ACK = 0x7F
} ab_message_type_t;

typedef struct {
    uint8_t type;
    uint8_t flags;
    uint8_t source_role;
    uint32_t source_id;
    uint32_t boot_id;
    uint32_t message_id;
} ab_frame_header_t;

typedef struct {
    ab_frame_header_t header;
    uint16_t payload_length;
    uint8_t payload[AB_MAX_PAYLOAD];
} ab_frame_t;

typedef void (*ab_frame_callback_t)(const ab_frame_t *frame, void *user);

typedef struct {
    uint8_t buffer[AB_MAX_FRAME];
    size_t used;
    size_t expected;
    uint32_t crc_errors;
    uint32_t format_errors;
    ab_frame_callback_t callback;
    void *user;
} ab_stream_parser_t;

uint16_t ab_crc16_ccitt(const uint8_t *data, size_t length);
size_t ab_frame_encode(const ab_frame_header_t *header,
                       const uint8_t *payload, uint16_t payload_length,
                       uint8_t *output, size_t output_capacity);
void ab_parser_init(ab_stream_parser_t *parser, ab_frame_callback_t callback, void *user);
void ab_parser_feed(ab_stream_parser_t *parser, const uint8_t *data, size_t length);

#endif
