/*
 * HMAC-SHA256 implementation (RFC 2104)
 * Depends on sha256.h
 */
#ifndef HMAC_SHA256_H
#define HMAC_SHA256_H

#include "sha256.h"

#ifdef __cplusplus
extern "C" {
#endif

#define HMAC_SHA256_DIGEST_SIZE 32

/* One-shot HMAC-SHA256 */
void hmac_sha256(const void* key, size_t key_len,
                 const void* data, size_t data_len,
                 uint8_t out[HMAC_SHA256_DIGEST_SIZE]);

/* Hex string output (64 chars + null) */
void hmac_sha256_hex(const void* key, size_t key_len,
                     const void* data, size_t data_len,
                     char hex[65]);

#ifdef __cplusplus
}
#endif

#endif /* HMAC_SHA256_H */
