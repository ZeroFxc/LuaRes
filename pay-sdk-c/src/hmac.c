/*
 * HMAC-SHA256 implementation (RFC 2104)
 */
#include "hmac.h"
#include <string.h>

void hmac_sha256(const void* key, size_t key_len,
                 const void* data, size_t data_len,
                 uint8_t out[HMAC_SHA256_DIGEST_SIZE]) {
    uint8_t k[SHA256_BLOCK_SIZE];
    uint8_t k_ipad[SHA256_BLOCK_SIZE];
    uint8_t k_opad[SHA256_BLOCK_SIZE];
    uint8_t inner_hash[SHA256_DIGEST_SIZE];
    sha256_ctx_t ctx;
    size_t i;

    /* Step 1: if key longer than block size, hash it; otherwise pad with zeros */
    memset(k, 0, SHA256_BLOCK_SIZE);
    if (key_len > SHA256_BLOCK_SIZE) {
        sha256(key, key_len, k);
    } else {
        memcpy(k, key, key_len);
    }

    /* Step 2: create padded keys */
    for (i = 0; i < SHA256_BLOCK_SIZE; i++) {
        k_ipad[i] = k[i] ^ 0x36;
        k_opad[i] = k[i] ^ 0x5c;
    }

    /* Step 3: inner hash = H(K ^ ipad || data) */
    sha256_init(&ctx);
    sha256_update(&ctx, k_ipad, SHA256_BLOCK_SIZE);
    sha256_update(&ctx, data, data_len);
    sha256_final(&ctx, inner_hash);

    /* Step 4: outer hash = H(K ^ opad || inner_hash) */
    sha256_init(&ctx);
    sha256_update(&ctx, k_opad, SHA256_BLOCK_SIZE);
    sha256_update(&ctx, inner_hash, SHA256_DIGEST_SIZE);
    sha256_final(&ctx, out);

    /* Clear sensitive data */
    memset(k, 0, sizeof(k));
    memset(k_ipad, 0, sizeof(k_ipad));
    memset(k_opad, 0, sizeof(k_opad));
    memset(inner_hash, 0, sizeof(inner_hash));
}

void hmac_sha256_hex(const void* key, size_t key_len,
                     const void* data, size_t data_len,
                     char hex[65]) {
    uint8_t digest[HMAC_SHA256_DIGEST_SIZE];
    int i;
    static const char hexchars[] = "0123456789abcdef";
    hmac_sha256(key, key_len, data, data_len, digest);
    for (i = 0; i < HMAC_SHA256_DIGEST_SIZE; i++) {
        hex[i * 2]     = hexchars[(digest[i] >> 4) & 0xF];
        hex[i * 2 + 1] = hexchars[digest[i] & 0xF];
    }
    hex[64] = '\0';
}
