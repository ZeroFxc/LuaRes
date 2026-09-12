/*
 * HTTP client abstraction layer
 * - Windows: WinHTTP (zero external dependency)
 * - Linux/macOS: libcurl
 */
#ifndef HTTP_H
#define HTTP_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char* key;
    const char* value;
} http_header_t;

typedef struct {
    int    status_code;   /* HTTP status code (200, 404, etc.) */
    char*  body;          /* Response body (null-terminated) */
    size_t body_len;      /* Body length */
    char   sign[512];     /* X-API-Sign response header */
    char   timestamp[64]; /* X-API-Timestamp response header */
    char   nonce[64];     /* X-API-Nonce response header */
    int    success;       /* 1 = network success, 0 = network failure */
    char   error[256];    /* Error message if success == 0 */
} http_response_t;

/* Perform an HTTP request.
   method: "GET" or "POST"
   url: full URL including https://
   body: request body for POST (NULL for GET)
   content_type: Content-Type header value (NULL to skip)
   headers: additional headers (NULL for none)
   header_count: number of additional headers
   Returns: allocated http_response_t (free with http_response_free) */
http_response_t* http_request(const char* method, const char* url,
                              const char* body, const char* content_type,
                              http_header_t* headers, int header_count);

/* Free an HTTP response */
void http_response_free(http_response_t* resp);

#ifdef __cplusplus
}
#endif

#endif /* HTTP_H */
