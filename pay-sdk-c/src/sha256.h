/*
 * SHA-256 implementation - public domain
 * Based on FIPS 180-4 specification
 */
#ifndef SHA256_H
#define SHA256_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SHA256_DIGEST_SIZE 32
#define SHA256_BLOCK_SIZE  64

typedef struct {
    uint32_t state[8];
    uint64_t bitlen;
    uint8_t  data[64];
    size_t   datalen;
} sha256_ctx_t;

void sha256_init(sha256_ctx_t* ctx);
void sha256_update(sha256_ctx_t* ctx, const void* data, size_t len);
void sha256_final(sha256_ctx_t* ctx, uint8_t digest[SHA256_DIGEST_SIZE]);

/* One-shot convenience */
void sha256(const void* data, size_t len, uint8_t digest[SHA256_DIGEST_SIZE]);

/* Hex string output (64 chars + null) */
void sha256_hex(const void* data, size_t len, char hex[65]);

#ifdef __cplusplus
}
#endif

#endif /* SHA256_H */
