/*
 * Base64 encode/decode
 */
#ifndef BASE64_H
#define BASE64_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Encodes data to base64 string. out must be large enough (4/3 * len + 1).
   Returns length of output string (excluding null terminator). */
size_t base64_encode(const void* data, size_t len, char* out);

/* Decodes base64 string to binary. out must be large enough (3/4 * len).
   Returns number of bytes decoded, or -1 on error. */
long base64_decode(const char* in, void* out, size_t out_max);

#ifdef __cplusplus
}
#endif

#endif /* BASE64_H */
