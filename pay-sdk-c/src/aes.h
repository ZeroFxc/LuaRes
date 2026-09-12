/*
 * AES-256-CBC implementation (FIPS 197)
 * Public domain implementation
 */
#ifndef AES_H
#define AES_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AES_BLOCK_SIZE 16

/* AES-256-CBC decryption.
   key:    32 bytes (256-bit key)
   iv:     16 bytes (initialization vector)
   cipher: ciphertext data
   len:    ciphertext length (must be multiple of 16)
   plain:  output buffer (at least len bytes)
   Returns 0 on success, -1 on error. */
int aes256_cbc_decrypt(const uint8_t key[32], const uint8_t iv[16],
                       const uint8_t* cipher, size_t len, uint8_t* plain);

/* AES-256-CBC encryption (for completeness) */
int aes256_cbc_encrypt(const uint8_t key[32], const uint8_t iv[16],
                       const uint8_t* plain, size_t len, uint8_t* cipher);

#ifdef __cplusplus
}
#endif

#endif /* AES_H */
