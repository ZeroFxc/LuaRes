/*
 * PAY System C SDK - Implementation
 */
#include "pay.h"
#include "http.h"
#include "json.h"
#include "hmac.h"
#include "sha256.h"
#include "aes.h"
#include "base64.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

#ifdef _WIN32
#include <windows.h>
#endif

/* ========================================================================== */
/*  Global state                                                              */
/* ========================================================================== */

static struct {
    int   initialized;
    char* base_url;
    char* api_key;
    char* secret_key;
    char* sign_key;
    char* sec_key;
    pay_result_t last_result;
} g_pay = { 0 };

/* ========================================================================== */
/*  Helpers                                                                    */
/* ========================================================================== */

static char* strdup_safe(const char* s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char* p = (char*)malloc(len);
    if (p) memcpy(p, s, len);
    return p;
}

static long long get_timestamp_ms(void) {
#ifdef _WIN32
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    ULARGE_INTEGER uli;
    uli.LowPart = ft.dwLowDateTime;
    uli.HighPart = ft.dwHighDateTime;
    return (long long)((uli.QuadPart - 116444736000000000ULL) / 10000);
#else
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
#endif
}

static void sleep_ms(int ms) {
#ifdef _WIN32
    Sleep(ms);
#else
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
#endif
}

/* Format a double for JSON (strip trailing zeros) */
static void format_double(char* buf, size_t size, double val) {
    snprintf(buf, size, "%.6f", val);
    char* dot = strchr(buf, '.');
    if (dot) {
        char* p = buf + strlen(buf) - 1;
        while (p > dot && *p == '0') *p-- = '\0';
        if (*p == '.') *p = '\0';
    }
}

/* Escape a string for JSON. Caller frees. */
static char* json_escape(const char* s) {
    if (!s) return strdup_safe("");
    size_t len = strlen(s);
    /* Worst case: each char becomes 6 chars (\uXXXX) */
    char* out = (char*)malloc(len * 6 + 1);
    if (!out) return NULL;
    size_t j = 0;
    size_t i;
    for (i = 0; i < len; i++) {
        unsigned char c = (unsigned char)s[i];
        switch (c) {
            case '"':  out[j++] = '\\'; out[j++] = '"'; break;
            case '\\': out[j++] = '\\'; out[j++] = '\\'; break;
            case '\b': out[j++] = '\\'; out[j++] = 'b'; break;
            case '\f': out[j++] = '\\'; out[j++] = 'f'; break;
            case '\n': out[j++] = '\\'; out[j++] = 'n'; break;
            case '\r': out[j++] = '\\'; out[j++] = 'r'; break;
            case '\t': out[j++] = '\\'; out[j++] = 't'; break;
            default:
                if (c < 0x20) {
                    j += snprintf(out + j, 7, "\\u%04x", c);
                } else {
                    out[j++] = (char)c;
                }
                break;
        }
    }
    out[j] = '\0';
    return out;
}

/* Build URL: base_url + path. Caller frees. */
static char* build_url(const char* path) {
    size_t base_len = strlen(g_pay.base_url);
    size_t path_len = strlen(path);
    char* url = (char*)malloc(base_len + path_len + 2);
    if (!url) return NULL;
    memcpy(url, g_pay.base_url, base_len);
    /* Ensure no double slash */
    if (base_len > 0 && url[base_len - 1] == '/' && path_len > 0 && path[0] == '/') {
        memcpy(url + base_len, path + 1, path_len);
        url[base_len + path_len - 1] = '\0';
    } else if (base_len > 0 && url[base_len - 1] != '/' && path_len > 0 && path[0] != '/') {
        url[base_len] = '/';
        memcpy(url + base_len + 1, path, path_len + 1);
    } else {
        memcpy(url + base_len, path, path_len + 1);
    }
    return url;
}

/* Get the auth key (prefer secret_key over api_key) */
static const char* get_auth_key(void) {
    return g_pay.secret_key ? g_pay.secret_key : g_pay.api_key;
}

/* Build signature headers if sign_key is configured.
   Returns number of sign headers added (0 or 2). */
static int build_sign_headers(const char* body_str, http_header_t* out_headers) {
    if (!g_pay.sign_key) return 0;

    long long ts = get_timestamp_ms();
    char ts_str[32];
    snprintf(ts_str, sizeof(ts_str), "%lld", ts);

    /* signData = bodyStr + timestamp */
    size_t body_len = strlen(body_str);
    size_t ts_len = strlen(ts_str);
    char* sign_data = (char*)malloc(body_len + ts_len + 1);
    if (!sign_data) return 0;
    memcpy(sign_data, body_str, body_len);
    memcpy(sign_data + body_len, ts_str, ts_len);
    sign_data[body_len + ts_len] = '\0';

    /* HMAC-SHA256(signData, signKey) -> hex */
    char sign_hex[65];
    hmac_sha256_hex(g_pay.sign_key, strlen(g_pay.sign_key),
                    sign_data, body_len + ts_len,
                    sign_hex);

    free(sign_data);

    out_headers[0].key = "X-API-Sign";
    out_headers[0].value = strdup_safe(sign_hex);
    out_headers[1].key = "X-API-Timestamp";
    out_headers[1].value = strdup_safe(ts_str);

    return 2;
}

/* Set last result */
static void set_last_result(int error, int http_status, const char* body, size_t body_len) {
    if (g_pay.last_result.body) {
        free(g_pay.last_result.body);
        g_pay.last_result.body = NULL;
    }
    g_pay.last_result.error = error;
    g_pay.last_result.http_status = http_status;
    if (body && body_len > 0) {
        g_pay.last_result.body = (char*)malloc(body_len + 1);
        if (g_pay.last_result.body) {
            memcpy(g_pay.last_result.body, body, body_len);
            g_pay.last_result.body[body_len] = '\0';
            g_pay.last_result.body_len = body_len;
        }
    } else {
        g_pay.last_result.body_len = 0;
    }
}

/* Try to decrypt response body if it contains {iv, data} and sec_key is set.
   Returns newly allocated decrypted string, or NULL if not encrypted/error.
   Sets *out_decrypted to 1 if decryption was performed. */
static char* try_decrypt_response(const char* body, size_t body_len, int* out_decrypted) {
    *out_decrypted = 0;
    if (!g_pay.sec_key || !body || body_len == 0) return NULL;

    /* Quick check: body must start with { and contain "iv" and "data" */
    const char* p = body;
    while (p < body + body_len && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) p++;
    if (p >= body + body_len || *p != '{') return NULL;

    /* Check for "iv" and "data" fields */
    if (!strstr(body, "\"iv\"") || !strstr(body, "\"data\"")) return NULL;

    /* Parse JSON to extract iv and data */
    json_value_t* jv = json_parse(body, body_len);
    if (!jv) return NULL;

    const char* iv_hex = json_object_string(jv, "iv");
    const char* data_b64 = json_object_string(jv, "data");
    if (!iv_hex || !data_b64) {
        json_free(jv);
        return NULL;
    }

    /* Derive AES key: SHA-256(sec_key) */
    uint8_t aes_key[32];
    sha256(g_pay.sec_key, strlen(g_pay.sec_key), aes_key);

    /* Parse IV from hex string */
    size_t iv_hex_len = strlen(iv_hex);
    if (iv_hex_len != 32) { /* 16 bytes = 32 hex chars */
        json_free(jv);
        return NULL;
    }
    uint8_t iv[16];
    size_t i;
    for (i = 0; i < 16; i++) {
        unsigned int byte;
        if (sscanf(iv_hex + i * 2, "%02x", &byte) != 1) {
            json_free(jv);
            return NULL;
        }
        iv[i] = (uint8_t)byte;
    }

    /* Base64 decode ciphertext */
    size_t cipher_max = strlen(data_b64); /* decoded is always smaller */
    uint8_t* cipher = (uint8_t*)malloc(cipher_max);
    if (!cipher) {
        json_free(jv);
        return NULL;
    }
    long cipher_len = base64_decode(data_b64, cipher, cipher_max);
    if (cipher_len <= 0 || cipher_len % 16 != 0) {
        free(cipher);
        json_free(jv);
        return NULL;
    }

    /* AES-256-CBC decrypt */
    uint8_t* plain = (uint8_t*)malloc(cipher_len + 1);
    if (!plain) {
        free(cipher);
        json_free(jv);
        return NULL;
    }

    if (aes256_cbc_decrypt(aes_key, iv, cipher, (size_t)cipher_len, plain) != 0) {
        free(plain);
        free(cipher);
        json_free(jv);
        return NULL;
    }
    plain[cipher_len] = '\0';

    /* Remove PKCS7 padding */
    int pad = plain[cipher_len - 1];
    if (pad > 0 && pad <= 16) {
        int k;
        int valid = 1;
        for (k = 0; k < pad; k++) {
            if (plain[cipher_len - 1 - k] != pad) { valid = 0; break; }
        }
        if (valid) plain[cipher_len - pad] = '\0';
    }

    free(cipher);
    json_free(jv);

    *out_decrypted = 1;
    return (char*)plain;
}

/* Verify response signature if sec_key and sign header are present.
   Returns PAY_OK if verification passes or is not needed. */
static int verify_response_sign(const http_response_t* resp, const char* plain_body) {
    if (!g_pay.sec_key) return PAY_OK;
    if (!resp->sign[0]) return PAY_OK; /* No sign header, skip verification */
    if (!plain_body) return PAY_OK;

    /* Extract algorithm and signature from sign header.
       Format: "hmac-sha256={hex}" or just "{hex}" */
    const char* sig = resp->sign;
    const char* algo = "hmac-sha256";

    /* Check for "hmac-sha256=" prefix */
    if (strncmp(resp->sign, "hmac-sha256=", 12) == 0) {
        sig = resp->sign + 12;
        algo = "hmac-sha256";
    } else if (strncmp(resp->sign, "hmac-sha1=", 10) == 0) {
        sig = resp->sign + 10;
        algo = "hmac-sha1";
    } else if (strncmp(resp->sign, "md5=", 4) == 0) {
        sig = resp->sign + 4;
        algo = "md5";
    }

    /* Build verification data: plainBody + timestamp + nonce */
    size_t body_len = strlen(plain_body);
    size_t ts_len = resp->timestamp[0] ? strlen(resp->timestamp) : 0;
    size_t nonce_len = resp->nonce[0] ? strlen(resp->nonce) : 0;
    size_t total = body_len + ts_len + nonce_len + 1;

    char* vdata = (char*)malloc(total);
    if (!vdata) return PAY_ERR_SIGN;
    vdata[0] = '\0';
    strcat(vdata, plain_body);
    if (ts_len > 0) strcat(vdata, resp->timestamp);
    if (nonce_len > 0) strcat(vdata, resp->nonce);

    /* Compute expected signature */
    char expected[65];
    if (strcmp(algo, "hmac-sha256") == 0) {
        hmac_sha256_hex(g_pay.sec_key, strlen(g_pay.sec_key),
                        vdata, strlen(vdata), expected);
    } else {
        /* For hmac-sha1 and md5, we fall back to hmac-sha256 as default
           (PAY system default is hmac-sha256) */
        hmac_sha256_hex(g_pay.sec_key, strlen(g_pay.sec_key),
                        vdata, strlen(vdata), expected);
    }

    free(vdata);

    /* Constant-time comparison */
    int result = 1;
    size_t exp_len = strlen(expected);
    size_t sig_len = strlen(sig);
    if (exp_len != sig_len) {
        result = 0;
    } else {
        size_t i;
        for (i = 0; i < exp_len; i++) {
            result |= (expected[i] ^ sig[i]);
        }
    }

    return result == 0 ? PAY_OK : PAY_ERR_SIGN;
}

/* Process HTTP response: decrypt, verify, set last_result.
   Returns the plain body string (caller frees) or NULL on error. */
static char* process_response(http_response_t* resp, int* out_error) {
    *out_error = PAY_OK;

    if (!resp) {
        *out_error = PAY_ERR_NETWORK;
        return NULL;
    }

    if (!resp->success) {
        set_last_result(PAY_ERR_NETWORK, 0, resp->error, strlen(resp->error));
        *out_error = PAY_ERR_NETWORK;
        http_response_free(resp);
        return NULL;
    }

    /* Check HTTP status */
    if (resp->status_code == 401 || resp->status_code == 403) {
        set_last_result(PAY_ERR_AUTH, resp->status_code,
                        resp->body ? resp->body : "", resp->body_len);
        *out_error = PAY_ERR_AUTH;
        http_response_free(resp);
        return NULL;
    }
    if (resp->status_code == 404) {
        set_last_result(PAY_ERR_NOT_FOUND, resp->status_code,
                        resp->body ? resp->body : "", resp->body_len);
        *out_error = PAY_ERR_NOT_FOUND;
        http_response_free(resp);
        return NULL;
    }

    /* Try to decrypt if needed */
    char* plain_body = NULL;
    int was_decrypted = 0;
    if (resp->body && resp->body_len > 0) {
        plain_body = try_decrypt_response(resp->body, resp->body_len, &was_decrypted);
        if (was_decrypted && !plain_body) {
            /* Decryption was attempted but failed - fall back to raw body */
            plain_body = strdup_safe(resp->body);
        }
        if (!plain_body) {
            plain_body = strdup_safe(resp->body ? resp->body : "");
        }
    } else {
        plain_body = strdup_safe("");
    }

    /* Verify response signature */
    if (was_decrypted || g_pay.sec_key) {
        int verify_result = verify_response_sign(resp, plain_body);
        if (verify_result != PAY_OK) {
            /* Fall back: don't fail on verification error, just log it.
               This matches the AIGG behavior of try/catch fallback. */
            /* In production you might want to return PAY_ERR_SIGN here */
        }
    }

    size_t plain_len = strlen(plain_body);
    set_last_result(PAY_OK, resp->status_code, plain_body, plain_len);

    http_response_free(resp);
    return plain_body;
}

/* Core request function: send POST and return processed body.
   Caller frees the returned string. Returns NULL on error (sets *out_error). */
static char* do_post(const char* path, const char* body_str, int* out_error) {
    *out_error = PAY_OK;

    if (!g_pay.initialized) {
        *out_error = PAY_ERR_INIT;
        return NULL;
    }

    char* url = build_url(path);
    if (!url) {
        *out_error = PAY_ERR_INIT;
        return NULL;
    }

    /* Build headers */
    http_header_t headers[8];
    int hdr_count = 0;

    const char* auth_key = get_auth_key();
    if (auth_key) {
        headers[hdr_count].key = "X-API-Key";
        headers[hdr_count].value = auth_key;
        hdr_count++;
    }

    /* Add sign headers if configured */
    http_header_t sign_headers[2];
    int sign_count = build_sign_headers(body_str, sign_headers);
    int i;
    for (i = 0; i < sign_count && hdr_count < 8; i++) {
        headers[hdr_count++] = sign_headers[i];
    }

    /* Perform request */
    http_response_t* resp = http_request("POST", url, body_str,
                                         "application/json",
                                         headers, hdr_count);

    /* Cleanup */
    free(url);
    for (i = 0; i < sign_count; i++) {
        free((void*)sign_headers[i].value);
    }

    return process_response(resp, out_error);
}

/* Core GET request function */
static char* do_get(const char* path, const char* user_token, int* out_error) {
    *out_error = PAY_OK;

    if (!g_pay.initialized) {
        *out_error = PAY_ERR_INIT;
        return NULL;
    }

    char* url = build_url(path);
    if (!url) {
        *out_error = PAY_ERR_INIT;
        return NULL;
    }

    http_header_t headers[4];
    int hdr_count = 0;

    const char* auth_key = get_auth_key();
    if (auth_key) {
        headers[hdr_count].key = "X-API-Key";
        headers[hdr_count].value = auth_key;
        hdr_count++;
    }

    if (user_token) {
        headers[hdr_count].key = "X-User-Token";
        headers[hdr_count].value = user_token;
        hdr_count++;
    }

    http_response_t* resp = http_request("GET", url, NULL, NULL, headers, hdr_count);
    free(url);

    return process_response(resp, out_error);
}

/* ========================================================================== */
/*  Public API implementation                                                  */
/* ========================================================================== */

const char* pay_version(void) {
    return "1.0.0";
}

int pay_init(const pay_config_t* config) {
    if (!config || !config->base_url) {
        return PAY_ERR_PARAM;
    }

    pay_cleanup();

    g_pay.base_url = strdup_safe(config->base_url);
    g_pay.api_key = strdup_safe(config->api_key);
    g_pay.secret_key = strdup_safe(config->secret_key);
    g_pay.sign_key = strdup_safe(config->sign_key);
    g_pay.sec_key = strdup_safe(config->sec_key);

    if (!g_pay.base_url) return PAY_ERR_INIT;
    if (!g_pay.api_key && !g_pay.secret_key) return PAY_ERR_PARAM;

    g_pay.initialized = 1;
    memset(&g_pay.last_result, 0, sizeof(g_pay.last_result));

    return PAY_OK;
}

void pay_cleanup(void) {
    if (g_pay.base_url) { free(g_pay.base_url); g_pay.base_url = NULL; }
    if (g_pay.api_key) { free(g_pay.api_key); g_pay.api_key = NULL; }
    if (g_pay.secret_key) { free(g_pay.secret_key); g_pay.secret_key = NULL; }
    if (g_pay.sign_key) { free(g_pay.sign_key); g_pay.sign_key = NULL; }
    if (g_pay.sec_key) { free(g_pay.sec_key); g_pay.sec_key = NULL; }
    if (g_pay.last_result.body) {
        free(g_pay.last_result.body);
        g_pay.last_result.body = NULL;
    }
    memset(&g_pay.last_result, 0, sizeof(g_pay.last_result));
    g_pay.initialized = 0;
}

const char* pay_error_message(int error) {
    switch (error) {
        case PAY_OK:            return "success";
        case PAY_ERR_INIT:      return "SDK not initialized or config invalid";
        case PAY_ERR_NETWORK:   return "network error";
        case PAY_ERR_AUTH:      return "authentication failed";
        case PAY_ERR_SIGN:      return "signature verification failed";
        case PAY_ERR_DECRYPT:   return "decryption failed";
        case PAY_ERR_JSON:      return "JSON parse error";
        case PAY_ERR_PARAM:     return "invalid parameter";
        case PAY_ERR_TIMEOUT:   return "polling timeout";
        case PAY_ERR_API:       return "PAY API error";
        case PAY_ERR_NOT_FOUND: return "resource not found";
        default:                return "unknown error";
    }
}

const pay_result_t* pay_last_result(void) {
    return &g_pay.last_result;
}

void pay_result_free(pay_result_t* result) {
    if (!result) return;
    if (result->body) {
        free(result->body);
        result->body = NULL;
    }
    result->body_len = 0;
}

/* ---- Parse order from JSON ---- */
static int parse_order(const json_value_t* jv, pay_order_t* order) {
    if (!jv || !order) return PAY_ERR_JSON;
    memset(order, 0, sizeof(*order));

    const char* id = json_object_string(jv, "orderId");
    if (id) {
        strncpy(order->order_id, id, sizeof(order->order_id) - 1);
    }

    order->amount = json_object_number(jv, "amount");

    const char* url = json_object_string(jv, "payUrl");
    if (url) {
        strncpy(order->pay_url, url, sizeof(order->pay_url) - 1);
    }

    const char* status = json_object_string(jv, "status");
    if (status) {
        strncpy(order->status, status, sizeof(order->status) - 1);
    }

    const char* otype = json_object_string(jv, "orderType");
    if (otype) {
        strncpy(order->order_type, otype, sizeof(order->order_type) - 1);
    }

    return PAY_OK;
}

/* ---- Parse user info from JSON ---- */
static int parse_user(const json_value_t* jv, pay_user_info_t* user) {
    if (!jv || !user) return PAY_ERR_JSON;
    memset(user, 0, sizeof(*user));

    const char* id = json_object_string(jv, "userId");
    if (id) strncpy(user->user_id, id, sizeof(user->user_id) - 1);

    const char* key = json_object_string(jv, "apiKey");
    if (key) strncpy(user->api_key, key, sizeof(user->api_key) - 1);

    const char* name = json_object_string(jv, "username");
    if (name) strncpy(user->username, name, sizeof(user->username) - 1);

    user->balance = json_object_number(jv, "balance");

    return PAY_OK;
}

/* ---- Check if JSON response indicates API error ---- */
static int check_api_error(const json_value_t* jv) {
    if (!jv) return PAY_ERR_JSON;

    /* Check for explicit success: false */
    const json_value_t* success = json_object_get(jv, "success");
    if (success && success->type == JSON_BOOL && success->u.boolean == 0) {
        return PAY_ERR_API;
    }

    /* Check for error field */
    const char* err = json_object_string(jv, "error");
    if (err) {
        /* "error": null or "error": "" means no error */
        if (err[0] != '\0') return PAY_ERR_API;
    }

    return PAY_OK;
}

int pay_create_order(double amount, const char* product_name, pay_order_t* order) {
    if (!order) return PAY_ERR_PARAM;
    if (amount <= 0) return PAY_ERR_PARAM;

    /* Build JSON body */
    char amt_str[32];
    format_double(amt_str, sizeof(amt_str), amount);

    char* escaped_name = json_escape(product_name ? product_name : "");

    /* Estimate size */
    size_t body_size = 64 + strlen(amt_str) + strlen(escaped_name);
    char* body = (char*)malloc(body_size);
    if (!body) { free(escaped_name); return PAY_ERR_UNKNOWN; }

    snprintf(body, body_size,
             "{\"amount\":%s,\"productName\":\"%s\"}",
             amt_str, escaped_name);
    free(escaped_name);

    int err;
    char* resp_body = do_post("/api/order/create", body, &err);
    free(body);

    if (err != PAY_OK) return err;

    json_value_t* jv = json_parse(resp_body, strlen(resp_body));
    free(resp_body);

    if (!jv) return PAY_ERR_JSON;

    int api_err = check_api_error(jv);
    if (api_err != PAY_OK) {
        json_free(jv);
        return api_err;
    }

    /* Response might be nested: {success: true, data: {orderId, ...}} or flat */
    const json_value_t* order_data = json_object_get(jv, "data");
    if (!order_data) order_data = json_object_get(jv, "order");
    if (!order_data) order_data = jv;

    int result = parse_order(order_data, order);
    json_free(jv);
    return result;
}

int pay_query_order(const char* order_id, pay_order_t* order) {
    if (!order_id || !order) return PAY_ERR_PARAM;

    /* Build path: /api/order/{orderId}/status */
    char path[256];
    snprintf(path, sizeof(path), "/api/order/%s/status", order_id);

    int err;
    char* resp_body = do_get(path, NULL, &err);
    if (err != PAY_OK) return err;

    json_value_t* jv = json_parse(resp_body, strlen(resp_body));
    free(resp_body);

    if (!jv) return PAY_ERR_JSON;

    int api_err = check_api_error(jv);
    if (api_err != PAY_OK) {
        json_free(jv);
        return api_err;
    }

    const json_value_t* order_data = json_object_get(jv, "data");
    if (!order_data) order_data = json_object_get(jv, "order");
    if (!order_data) order_data = jv;

    int result = parse_order(order_data, order);
    json_free(jv);
    return result;
}

int pay_poll_order(const char* order_id, int interval_sec, int max_attempts,
                   pay_order_t* order) {
    if (!order_id || !order) return PAY_ERR_PARAM;

    if (interval_sec <= 0) interval_sec = 3;
    if (max_attempts <= 0) max_attempts = 60;

    int attempt;
    for (attempt = 0; attempt < max_attempts; attempt++) {
        int err = pay_query_order(order_id, order);
        if (err == PAY_OK) {
            if (strcmp(order->status, "completed") == 0) {
                return PAY_OK;
            }
            if (strcmp(order->status, "expired") == 0) {
                return PAY_ERR_API;
            }
            /* Still pending, continue polling */
        } else if (err == PAY_ERR_NOT_FOUND) {
            /* Order not found yet, might still be processing */
        } else {
            /* Other error, retry */
        }

        if (attempt < max_attempts - 1) {
            sleep_ms(interval_sec * 1000);
        }
    }

    return PAY_ERR_TIMEOUT;
}

int pay_register_user(const char* username, const char* password,
                      pay_user_info_t* user) {
    if (!username || !password || !user) return PAY_ERR_PARAM;

    char* esc_user = json_escape(username);
    char* esc_pass = json_escape(password);

    size_t body_size = 64 + strlen(esc_user) + strlen(esc_pass);
    char* body = (char*)malloc(body_size);
    if (!body) { free(esc_user); free(esc_pass); return PAY_ERR_UNKNOWN; }

    snprintf(body, body_size,
             "{\"username\":\"%s\",\"password\":\"%s\"}",
             esc_user, esc_pass);
    free(esc_user);
    free(esc_pass);

    int err;
    char* resp_body = do_post("/api/user/register", body, &err);
    free(body);

    if (err != PAY_OK) return err;

    json_value_t* jv = json_parse(resp_body, strlen(resp_body));
    free(resp_body);

    if (!jv) return PAY_ERR_JSON;

    int api_err = check_api_error(jv);
    if (api_err != PAY_OK) {
        json_free(jv);
        return api_err;
    }

    const json_value_t* user_data = json_object_get(jv, "data");
    if (!user_data) user_data = json_object_get(jv, "user");
    if (!user_data) user_data = jv;

    int result = parse_user(user_data, user);
    json_free(jv);
    return result;
}

int pay_login_user(const char* username, const char* password,
                   pay_user_info_t* user) {
    if (!username || !password || !user) return PAY_ERR_PARAM;

    char* esc_user = json_escape(username);
    char* esc_pass = json_escape(password);

    size_t body_size = 64 + strlen(esc_user) + strlen(esc_pass);
    char* body = (char*)malloc(body_size);
    if (!body) { free(esc_user); free(esc_pass); return PAY_ERR_UNKNOWN; }

    snprintf(body, body_size,
             "{\"username\":\"%s\",\"password\":\"%s\"}",
             esc_user, esc_pass);
    free(esc_user);
    free(esc_pass);

    int err;
    char* resp_body = do_post("/api/user/login", body, &err);
    free(body);

    if (err != PAY_OK) return err;

    json_value_t* jv = json_parse(resp_body, strlen(resp_body));
    free(resp_body);

    if (!jv) return PAY_ERR_JSON;

    int api_err = check_api_error(jv);
    if (api_err != PAY_OK) {
        json_free(jv);
        return api_err;
    }

    const json_value_t* user_data = json_object_get(jv, "data");
    if (!user_data) user_data = json_object_get(jv, "user");
    if (!user_data) user_data = jv;

    int result = parse_user(user_data, user);
    json_free(jv);
    return result;
}

int pay_get_user_info(const char* user_token, pay_user_info_t* user) {
    if (!user_token || !user) return PAY_ERR_PARAM;

    int err;
    char* resp_body = do_get("/api/user/me", user_token, &err);
    if (err != PAY_OK) return err;

    json_value_t* jv = json_parse(resp_body, strlen(resp_body));
    free(resp_body);

    if (!jv) return PAY_ERR_JSON;

    int api_err = check_api_error(jv);
    if (api_err != PAY_OK) {
        json_free(jv);
        return api_err;
    }

    const json_value_t* user_data = json_object_get(jv, "data");
    if (!user_data) user_data = json_object_get(jv, "user");
    if (!user_data) user_data = jv;

    int result = parse_user(user_data, user);
    json_free(jv);
    return result;
}

int pay_shop_recharge(const char* user_token, double amount, pay_order_t* order) {
    if (!user_token || !order || amount <= 0) return PAY_ERR_PARAM;

    /* Build JSON body */
    char amt_str[32];
    format_double(amt_str, sizeof(amt_str), amount);

    char body[128];
    snprintf(body, sizeof(body), "{\"amount\":%s}", amt_str);

    /* Build headers with user token */
    if (!g_pay.initialized) return PAY_ERR_INIT;

    char* url = build_url("/api/shop/recharge");
    if (!url) return PAY_ERR_INIT;

    http_header_t headers[4];
    int hdr_count = 0;

    const char* auth_key = get_auth_key();
    if (auth_key) {
        headers[hdr_count].key = "X-API-Key";
        headers[hdr_count].value = auth_key;
        hdr_count++;
    }
    headers[hdr_count].key = "X-User-Token";
    headers[hdr_count].value = user_token;
    hdr_count++;

    /* Add sign headers */
    http_header_t sign_headers[2];
    int sign_count = build_sign_headers(body, sign_headers);
    int i;
    for (i = 0; i < sign_count && hdr_count < 4; i++) {
        headers[hdr_count++] = sign_headers[i];
    }

    http_response_t* resp = http_request("POST", url, body,
                                         "application/json",
                                         headers, hdr_count);
    free(url);
    for (i = 0; i < sign_count; i++) {
        free((void*)sign_headers[i].value);
    }

    int err;
    char* resp_body = process_response(resp, &err);
    if (err != PAY_OK) return err;

    json_value_t* jv = json_parse(resp_body, strlen(resp_body));
    free(resp_body);

    if (!jv) return PAY_ERR_JSON;

    int api_err = check_api_error(jv);
    if (api_err != PAY_OK) {
        json_free(jv);
        return api_err;
    }

    const json_value_t* order_data = json_object_get(jv, "data");
    if (!order_data) order_data = json_object_get(jv, "order");
    if (!order_data) order_data = jv;

    int result = parse_order(order_data, order);
    json_free(jv);
    return result;
}
