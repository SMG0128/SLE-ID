#ifndef SLE_AB_DUAL_CLIENT_H
#define SLE_AB_DUAL_CLIENT_H

#include <stdbool.h>
#include <stdint.h>

#include "errcode.h"

typedef void (*sle_ab_dual_rx_fn)(const uint8_t *data, uint16_t length, void *user);

typedef struct {
    sle_ab_dual_rx_fn b_receive;
    sle_ab_dual_rx_fn card_receive;
    void *user;
} sle_ab_dual_client_callbacks_t;

errcode_t sle_ab_dual_client_init(const sle_ab_dual_client_callbacks_t *callbacks);
bool sle_ab_dual_client_send_b(const uint8_t *data, uint16_t length);
bool sle_ab_dual_client_send_card(const uint8_t *data, uint16_t length);
bool sle_ab_dual_client_b_ready(void);
bool sle_ab_dual_client_card_ready(void);
void sle_ab_dual_client_status(void);

#endif
