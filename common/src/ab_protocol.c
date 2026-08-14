#include "ab_protocol.h"

#include <string.h>

#define AB_MAGIC_0 0x53U
#define AB_MAGIC_1 0x4CU

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

uint16_t ab_crc16_ccitt(const uint8_t *data, size_t length)
{
    uint16_t crc = 0xFFFFU;
    size_t i;
    uint8_t bit;
    for (i = 0; i < length; ++i) {
        crc ^= (uint16_t)data[i] << 8;
        for (bit = 0; bit < 8U; ++bit) {
            crc = (crc & 0x8000U) ? (uint16_t)((crc << 1) ^ 0x1021U) : (uint16_t)(crc << 1);
        }
    }
    return crc;
}

size_t ab_frame_encode(const ab_frame_header_t *header,
                       const uint8_t *payload, uint16_t payload_length,
                       uint8_t *output, size_t output_capacity)
{
    size_t total = AB_FRAME_OVERHEAD + payload_length;
    uint16_t crc;
    if (header == NULL || output == NULL || payload_length > AB_MAX_PAYLOAD ||
        output_capacity < total || header->source_role > AB_ROLE_HOST ||
        (payload_length != 0U && payload == NULL)) {
        return 0U;
    }
    output[0] = AB_MAGIC_0;
    output[1] = AB_MAGIC_1;
    output[2] = AB_PROTOCOL_VERSION;
    output[3] = header->type;
    output[4] = header->flags;
    output[5] = header->source_role;
    write_u32(&output[6], header->source_id);
    write_u32(&output[10], header->boot_id);
    write_u32(&output[14], header->message_id);
    write_u16(&output[18], payload_length);
    if (payload_length != 0U) {
        (void)memcpy(&output[AB_FRAME_HEADER_SIZE], payload, payload_length);
    }
    crc = ab_crc16_ccitt(&output[2], (AB_FRAME_HEADER_SIZE - 2U) + payload_length);
    write_u16(&output[AB_FRAME_HEADER_SIZE + payload_length], crc);
    return total;
}

void ab_parser_init(ab_stream_parser_t *parser, ab_frame_callback_t callback, void *user)
{
    if (parser == NULL) return;
    (void)memset(parser, 0, sizeof(*parser));
    parser->callback = callback;
    parser->user = user;
}

static void parser_reset(ab_stream_parser_t *parser)
{
    parser->used = 0U;
    parser->expected = 0U;
}

static void parser_accept(ab_stream_parser_t *parser)
{
    ab_frame_t frame;
    uint16_t payload_length = read_u16(&parser->buffer[18]);
    uint16_t expected_crc = read_u16(&parser->buffer[AB_FRAME_HEADER_SIZE + payload_length]);
    uint16_t actual_crc = ab_crc16_ccitt(&parser->buffer[2],
                                          (AB_FRAME_HEADER_SIZE - 2U) + payload_length);
    if (expected_crc != actual_crc) {
        parser->crc_errors++;
        parser_reset(parser);
        return;
    }
    (void)memset(&frame, 0, sizeof(frame));
    frame.header.type = parser->buffer[3];
    frame.header.flags = parser->buffer[4];
    frame.header.source_role = parser->buffer[5];
    frame.header.source_id = read_u32(&parser->buffer[6]);
    frame.header.boot_id = read_u32(&parser->buffer[10]);
    frame.header.message_id = read_u32(&parser->buffer[14]);
    frame.payload_length = payload_length;
    if (payload_length != 0U) {
        (void)memcpy(frame.payload, &parser->buffer[AB_FRAME_HEADER_SIZE], payload_length);
    }
    parser_reset(parser);
    if (parser->callback != NULL) parser->callback(&frame, parser->user);
}

void ab_parser_feed(ab_stream_parser_t *parser, const uint8_t *data, size_t length)
{
    size_t i;
    if (parser == NULL || data == NULL) return;
    for (i = 0; i < length; ++i) {
        uint8_t byte = data[i];
        if (parser->used == 0U) {
            if (byte == AB_MAGIC_0) parser->buffer[parser->used++] = byte;
            continue;
        }
        if (parser->used == 1U) {
            if (byte == AB_MAGIC_1) parser->buffer[parser->used++] = byte;
            else if (byte != AB_MAGIC_0) parser_reset(parser);
            continue;
        }
        if (parser->used >= AB_MAX_FRAME) {
            parser->format_errors++;
            parser_reset(parser);
            if (byte == AB_MAGIC_0) parser->buffer[parser->used++] = byte;
            continue;
        }
        parser->buffer[parser->used++] = byte;
        if (parser->used == AB_FRAME_HEADER_SIZE) {
            uint16_t payload_length = read_u16(&parser->buffer[18]);
            if (parser->buffer[2] != AB_PROTOCOL_VERSION ||
                parser->buffer[5] > AB_ROLE_HOST || payload_length > AB_MAX_PAYLOAD) {
                parser->format_errors++;
                parser_reset(parser);
                if (byte == AB_MAGIC_0) parser->buffer[parser->used++] = byte;
                continue;
            }
            parser->expected = AB_FRAME_OVERHEAD + payload_length;
        }
        if (parser->expected != 0U && parser->used == parser->expected) parser_accept(parser);
    }
}
