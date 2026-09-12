/*
 * PAY System C SDK
 * Cross-platform C API for PAY payment system
 *
 * Features:
 *   - Create orders, query status, poll until complete
 *   - User registration and login
 *   - HMAC-SHA256 request signing
 *   - Optional AES-256-CBC response decryption
 *   - Optional response signature verification
 *   - Works on Windows (WinHTTP), Linux/macOS (libcurl)
 */
#ifndef PAY_H
#define PAY_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

/* ========================================================================== */
/*  Error codes                                                               */
/* ========================================================================== */
typedef enum {
    PAY_OK            = 0,
    PAY_ERR_INIT      = -1,   /* SDK not initialized or config invalid */
    PAY_ERR_NETWORK   = -2,   /* Network/HTTP failure */
    PAY_ERR_AUTH      = -3,   /* Authentication failure (401/403) */
    PAY_ERR_SIGN      = -4,   /* Signature verification failed */
    PAY_ERR_DECRYPT   = -5,   /* AES decryption failed */
    PAY_ERR_JSON      = -6,   /* JSON parse error */
    PAY_ERR_PARAM     = -7,   /* Invalid parameter */
    PAY_ERR_TIMEOUT   = -8,   /* Polling timeout */
    PAY_ERR_API       = -9,   /* PAY API returned error */
    PAY_ERR_NOT_FOUND = -10,  /* Resource not found (404) */
    PAY_ERR_UNKNOWN   = -99   /* Unknown error */
} pay_error_t;

/* ========================================================================== */
/*  Data structures                                                           */
/* ========================================================================== */

/* SDK configuration */
typedef struct {
    const char* base_url;    /* e.g. "https://pay.xn--kiv483g.online" */
    const char* api_key;     /* pk_ public key */
    const char* secret_key;  /* sk_ private key (preferred for auth) */
    const char* sign_key;    /* HMAC request signing key (optional) */
    const char* sec_key;     /* Response verification / AES key (optional) */
} pay_config_t;

/* Order information */
typedef struct {
    char   order_id[128];
    double amount;
    char   pay_url[512];
    char   status[32];       /* pending / completed / expired */
    char   order_type[32];   /* merchant / recharge */
} pay_order_t;

/* User information */
typedef struct {
    char   user_id[64];
    char   api_key[128];
    char   username[128];
    double balance;
} pay_user_info_t;

/* Generic API result (for advanced use) */
typedef struct {
    int    error;            /* pay_error_t code */
    int    http_status;      /* HTTP status code */
    char*  body;             /* Response body (null-terminated, may be decrypted) */
    size_t body_len;         /* Body length */
} pay_result_t;

/* ========================================================================== */
/*  Core functions                                                            */
/* ========================================================================== */

/* Initialize the SDK with configuration. Returns PAY_OK on success. */
int pay_init(const pay_config_t* config);

/* Cleanup SDK resources. */
void pay_cleanup(void);

/* ========================================================================== */
/*  Merchant payment API                                                      */
/* ========================================================================== */

/* Create a payment order.
   amount:      payment amount (e.g. 99.99)
   product_name: product description (can be NULL)
   order:       output order info
   Returns PAY_OK on success. */
int pay_create_order(double amount, const char* product_name, pay_order_t* order);

/* Query order status by orderId.
   Returns PAY_OK on success, fills order struct. */
int pay_query_order(const char* order_id, pay_order_t* order);

/* Poll order status until completed, expired, or timeout.
   interval_sec:  polling interval in seconds (use 0 for default 3s)
   max_attempts:  max polling attempts (use 0 for default 60)
   Returns PAY_OK when status becomes "completed",
           PAY_ERR_TIMEOUT if max attempts reached,
           PAY_ERR_API if status becomes "expired". */
int pay_poll_order(const char* order_id, int interval_sec, int max_attempts,
                   pay_order_t* order);

/* ========================================================================== */
/*  User API                                                                  */
/* ========================================================================== */

/* Register a new user.
   Returns PAY_OK on success, fills user info (apiKey, userId). */
int pay_register_user(const char* username, const char* password,
                      pay_user_info_t* user);

/* Login with username and password.
   Returns PAY_OK on success, fills user info. */
int pay_login_user(const char* username, const char* password,
                   pay_user_info_t* user);

/* Get current user info (requires X-User-Token).
   user_token: the token from login/register (e.g. "user-12345")
   Returns PAY_OK on success. */
int pay_get_user_info(const char* user_token, pay_user_info_t* user);

/* ========================================================================== */
/*  Shop API                                                                  */
/* ========================================================================== */

/* Create a recharge order (shop user).
   user_token: user token
   amount:     recharge amount
   order:      output order info
   Returns PAY_OK on success. */
int pay_shop_recharge(const char* user_token, double amount, pay_order_t* order);

/* ========================================================================== */
/*  Utilities                                                                 */
/* ========================================================================== */

/* Get human-readable error message for an error code. */
const char* pay_error_message(int error);

/* Get the last API result (for debugging). Returns NULL if no request made. */
const pay_result_t* pay_last_result(void);

/* Free a result's body memory (usually not needed, managed internally). */
void pay_result_free(pay_result_t* result);

/* Get SDK version string. */
const char* pay_version(void);

#ifdef __cplusplus
}
#endif

#endif /* PAY_H */
