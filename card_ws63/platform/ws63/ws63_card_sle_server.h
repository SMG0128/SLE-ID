#ifndef SLE_WS63_CARD_SLE_SERVER_H
#define SLE_WS63_CARD_SLE_SERVER_H

#include <stdbool.h>
#include <stdint.h>

#include "errcode.h"

#define WS63_CARD_SERVICE_UUID 0x2C00U
#define WS63_CARD_INFO_UUID 0x2C01U
#define WS63_CARD_COMMAND_UUID 0x2C02U
#define WS63_CARD_RESPONSE_UUID 0x2C03U
#define WS63_CARD_STATUS_UUID 0x2C04U

typedef bool (*ws63_card_sle_command_fn)(const uint8_t *data, uint16_t length, void *user);
typedef uint16_t (*ws63_card_sle_read_fn)(uint16_t property_handle, uint8_t *output,
                                         uint16_t capacity, void *user);
typedef void (*ws63_card_sle_connection_fn)(bool connected, void *user);

typedef struct {
    ws63_card_sle_command_fn command;
    ws63_card_sle_read_fn read;
    ws63_card_sle_connection_fn connection;
    void *user;
} ws63_card_sle_callbacks_t;

errcode_t ws63_card_sle_server_init(const ws63_card_sle_callbacks_t *callbacks);
errcode_t ws63_card_sle_start_advertising(void);
errcode_t ws63_card_sle_send_response(const uint8_t *data, uint16_t length);
errcode_t ws63_card_sle_send_status(const uint8_t *data, uint16_t length);
bool ws63_card_sle_is_connected(void);
uint16_t ws63_card_sle_info_handle(void);
uint16_t ws63_card_sle_status_handle(void);

#endif
