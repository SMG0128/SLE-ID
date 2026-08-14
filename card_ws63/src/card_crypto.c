#include "card_crypto.h"

#include <string.h>

#define SHA256_BLOCK_SIZE 64U

typedef struct {
    uint32_t state[8];
    uint64_t bit_length;
    uint8_t block[SHA256_BLOCK_SIZE];
    size_t used;
} sha256_context_t;

static const uint32_t g_sha256_k[64] = {
    0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U,
    0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
    0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U,
    0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
    0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
    0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
    0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
    0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
    0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU,
    0x5b9cca4fU, 0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
    0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U
};

static uint32_t rotate_right(uint32_t value, uint8_t shift)
{
    return (value >> shift) | (value << (32U - shift));
}

static uint32_t read_be32(const uint8_t *data)
{
    return ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) |
           ((uint32_t)data[2] << 8) | data[3];
}

static void write_be32(uint8_t *data, uint32_t value)
{
    data[0] = (uint8_t)(value >> 24);
    data[1] = (uint8_t)(value >> 16);
    data[2] = (uint8_t)(value >> 8);
    data[3] = (uint8_t)value;
}

static void sha256_transform(sha256_context_t *context, const uint8_t *block)
{
    uint32_t words[64];
    uint32_t a, b, c, d, e, f, g, h;
    uint32_t i;
    for (i = 0U; i < 16U; ++i) words[i] = read_be32(&block[i * 4U]);
    for (; i < 64U; ++i) {
        uint32_t s0 = rotate_right(words[i - 15U], 7U) ^
                      rotate_right(words[i - 15U], 18U) ^ (words[i - 15U] >> 3);
        uint32_t s1 = rotate_right(words[i - 2U], 17U) ^
                      rotate_right(words[i - 2U], 19U) ^ (words[i - 2U] >> 10);
        words[i] = words[i - 16U] + s0 + words[i - 7U] + s1;
    }
    a = context->state[0]; b = context->state[1]; c = context->state[2]; d = context->state[3];
    e = context->state[4]; f = context->state[5]; g = context->state[6]; h = context->state[7];
    for (i = 0U; i < 64U; ++i) {
        uint32_t sum1 = rotate_right(e, 6U) ^ rotate_right(e, 11U) ^ rotate_right(e, 25U);
        uint32_t choose = (e & f) ^ ((~e) & g);
        uint32_t temp1 = h + sum1 + choose + g_sha256_k[i] + words[i];
        uint32_t sum0 = rotate_right(a, 2U) ^ rotate_right(a, 13U) ^ rotate_right(a, 22U);
        uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
        uint32_t temp2 = sum0 + majority;
        h = g; g = f; f = e; e = d + temp1; d = c; c = b; b = a; a = temp1 + temp2;
    }
    context->state[0] += a; context->state[1] += b; context->state[2] += c;
    context->state[3] += d; context->state[4] += e; context->state[5] += f;
    context->state[6] += g; context->state[7] += h;
}

static void sha256_init(sha256_context_t *context)
{
    static const uint32_t initial[8] = {
        0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU,
        0x510e527fU, 0x9b05688cU, 0x1f83d9abU, 0x5be0cd19U
    };
    (void)memset(context, 0, sizeof(*context));
    (void)memcpy(context->state, initial, sizeof(initial));
}

static void sha256_update(sha256_context_t *context, const uint8_t *data, size_t length)
{
    size_t amount;
    if (length == 0U) return;
    while (length != 0U) {
        amount = SHA256_BLOCK_SIZE - context->used;
        if (amount > length) amount = length;
        (void)memcpy(&context->block[context->used], data, amount);
        context->used += amount;
        data += amount;
        length -= amount;
        if (context->used == SHA256_BLOCK_SIZE) {
            sha256_transform(context, context->block);
            context->bit_length += 512U;
            context->used = 0U;
        }
    }
}

static void sha256_final(sha256_context_t *context, uint8_t output[CARD_SHA256_SIZE])
{
    uint64_t total_bits = context->bit_length + (uint64_t)context->used * 8U;
    uint8_t i;
    context->block[context->used++] = 0x80U;
    if (context->used > 56U) {
        (void)memset(&context->block[context->used], 0, SHA256_BLOCK_SIZE - context->used);
        sha256_transform(context, context->block);
        context->used = 0U;
    }
    (void)memset(&context->block[context->used], 0, 56U - context->used);
    for (i = 0U; i < 8U; ++i)
        context->block[63U - i] = (uint8_t)(total_bits >> (i * 8U));
    sha256_transform(context, context->block);
    for (i = 0U; i < 8U; ++i) write_be32(&output[i * 4U], context->state[i]);
    (void)memset(context, 0, sizeof(*context));
}

void card_hmac_sha256(const uint8_t *key, size_t key_length,
                      const uint8_t *data, size_t data_length,
                      uint8_t output[CARD_SHA256_SIZE])
{
    uint8_t key_block[SHA256_BLOCK_SIZE] = { 0U };
    uint8_t inner_pad[SHA256_BLOCK_SIZE];
    uint8_t outer_pad[SHA256_BLOCK_SIZE];
    uint8_t inner_hash[CARD_SHA256_SIZE];
    sha256_context_t context;
    size_t i;
    if (output == NULL || (key_length != 0U && key == NULL) ||
        (data_length != 0U && data == NULL)) return;
    if (key_length > SHA256_BLOCK_SIZE) {
        sha256_init(&context);
        sha256_update(&context, key, key_length);
        sha256_final(&context, key_block);
    } else if (key_length != 0U) {
        (void)memcpy(key_block, key, key_length);
    }
    for (i = 0U; i < SHA256_BLOCK_SIZE; ++i) {
        inner_pad[i] = key_block[i] ^ 0x36U;
        outer_pad[i] = key_block[i] ^ 0x5cU;
    }
    sha256_init(&context);
    sha256_update(&context, inner_pad, sizeof(inner_pad));
    sha256_update(&context, data, data_length);
    sha256_final(&context, inner_hash);
    sha256_init(&context);
    sha256_update(&context, outer_pad, sizeof(outer_pad));
    sha256_update(&context, inner_hash, sizeof(inner_hash));
    sha256_final(&context, output);
    (void)memset(key_block, 0, sizeof(key_block));
    (void)memset(inner_pad, 0, sizeof(inner_pad));
    (void)memset(outer_pad, 0, sizeof(outer_pad));
    (void)memset(inner_hash, 0, sizeof(inner_hash));
}

int card_constant_time_equal(const uint8_t *left, const uint8_t *right, size_t length)
{
    uint8_t difference = 0U;
    size_t i;
    if (left == NULL || right == NULL) return 0;
    for (i = 0U; i < length; ++i) difference |= left[i] ^ right[i];
    return difference == 0U;
}
