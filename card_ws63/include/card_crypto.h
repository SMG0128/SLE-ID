#ifndef SLE_CARD_CRYPTO_H
#define SLE_CARD_CRYPTO_H

#include <stddef.h>
#include <stdint.h>

#define CARD_SHA256_SIZE 32U

void card_hmac_sha256(const uint8_t *key, size_t key_length,
                      const uint8_t *data, size_t data_length,
                      uint8_t output[CARD_SHA256_SIZE]);
int card_constant_time_equal(const uint8_t *left, const uint8_t *right, size_t length);

#endif
