/*
 * Base64 encode/decode
 */
#include "base64.h"
#include <string.h>
#include <stdint.h>

static const char b64_table[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

size_t base64_encode(const void* data, size_t len, char* out) {
    const uint8_t* p = (const uint8_t*)data;
    size_t i, j = 0;

    for (i = 0; i + 3 <= len; i += 3) {
        out[j++] = b64_table[p[i] >> 2];
        out[j++] = b64_table[((p[i] & 0x03) << 4) | (p[i + 1] >> 4)];
        out[j++] = b64_table[((p[i + 1] & 0x0F) << 2) | (p[i + 2] >> 6)];
        out[j++] = b64_table[p[i + 2] & 0x3F];
    }

    if (i < len) {
        out[j++] = b64_table[p[i] >> 2];
        if (len - i == 1) {
            out[j++] = b64_table[(p[i] & 0x03) << 4];
            out[j++] = '=';
            out[j++] = '=';
        } else {
            out[j++] = b64_table[((p[i] & 0x03) << 4) | (p[i + 1] >> 4)];
            out[j++] = b64_table[(p[i + 1] & 0x0F) << 2];
            out[j++] = '=';
        }
    }

    out[j] = '\0';
    return j;
}

static int b64_val(char c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}

long base64_decode(const char* in, void* out, size_t out_max) {
    size_t len = strlen(in);
    uint8_t* o = (uint8_t*)out;
    size_t i = 0, j = 0;
    int buf[4];

    while (i < len) {
        int k = 0;
        while (k < 4 && i < len) {
            if (in[i] == '=') {
                buf[k++] = -2; /* padding */
                i++;
            } else if (in[i] == '\n' || in[i] == '\r' || in[i] == ' ' || in[i] == '\t') {
                i++;
            } else {
                int v = b64_val(in[i]);
                if (v < 0) return -1;
                buf[k++] = v;
                i++;
            }
        }
        if (k < 4) break;

        if (j >= out_max) return -1;
        o[j++] = (uint8_t)((buf[0] << 2) | (buf[1] >> 4));
        if (buf[2] != -2) {
            if (j >= out_max) return -1;
            o[j++] = (uint8_t)((buf[1] << 4) | (buf[2] >> 2));
            if (buf[3] != -2) {
                if (j >= out_max) return -1;
                o[j++] = (uint8_t)((buf[2] << 6) | buf[3]);
            }
        }
    }

    return (long)j;
}
