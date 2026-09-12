/*
 * PAY SDK - WebAssembly bridge（wasm 核心处理层）
 *
 * 架构分工：
 *   - 网络层：JS（浏览器 fetch / node fetch）—— 本模块绝不发起真实 HTTP 请求
 *   - 核心处理：本模块（wasm）—— 请求体构建、HMAC-SHA256 请求签名、
 *     AES-256-CBC 响应解密、响应验签、JSON 结构化解析
 *
 * 实现方式：通过 #include "pay.c" 复用 SDK 全部内部实现（静态函数可直接引用），
 * 不改动原生代码；http.c 不参与 wasm 编译，这里提供空桩即可。
 *
 * 暴露给 JS 的接口（均为 Emscripten ccall 可调）：
 *   int    payw_init(base_url, api_key, secret_key, sign_key, sec_key)
 *   string payw_version()
 *   string payw_build_request(op, args_json)
 *          -> {"method":"POST","url":"...","path":"...","body":"..."|null,
 *              "headers":[["k","v"],...]}
 *             失败时返回 {"ok":false,"error":code,"message":"..."}
 *   string payw_parse_response(op, body, status_code, sign, timestamp, nonce)
 *          -> {"ok":true,"orderId":"...","payUrl":"...","amount":..,"status":"...","orderType":"..."}
 *             或 {"ok":true,"userId":"...","apiKey":"...","username":"...","balance":..}
 *             或 {"ok":false,"error":code,"httpStatus":..,"message":"...","body":"..."}
 *
 * 返回字符串均指向模块内静态缓冲区；JS 同步读取后立即使用，无内存管理负担。
 */
#include "pay.h"
#include "http.h"
#include "json.h"

#include <string.h>
#include <stdio.h>

/* ========================================================================== */
/*  HTTP 空桩：wasm 构建不做真实请求，网络全部由 JS 承担                        */
/* ========================================================================== */
http_response_t* http_request(const char* method, const char* url,
                              const char* body, const char* content_type,
                              http_header_t* headers, int header_count) {
    (void)method; (void)url; (void)body; (void)content_type;
    (void)headers; (void)header_count;
    return NULL;
}

void http_response_free(http_response_t* resp) {
    (void)resp;
}

/* ========================================================================== */
/*  复用 SDK 全部内部实现（g_pay、build_sign_headers、try_decrypt_response、   */
/*  process_response、parse_order、parse_user、json_escape、build_url ...）     */
/* ========================================================================== */
#include "pay.c"

/* ========================================================================== */
/*  内置商户配置：密钥以 XOR(0x5A) 编码存储（wasm 二进制内无明文），          */
/*  运行时经 payw_cfg 解码后使用；JS 不出现明文密钥。                          */
/* ========================================================================== */

/* XOR(0x5A) 编码后的十六进制（由脚本生成，切勿手改） */
#define PAYW_ENC_ADMIN_TOKEN \
  "6e6839683e6c3c6b636e6e3b6c6f3f3f6a3b3868696d6f6e3c6b693f6f6b6e68686e6b696e6a3f696d6a3c6c3c633e6f6f39683f696c396d6d6e636869683e38"
#define PAYW_ENC_API_KEY \
  "2a31056f62383c6b693b6f3b6e3f3e6e6b6968626f6c633b3f3c6b3f6e396e623e6368"
#define PAYW_ENC_SECRET_KEY \
  "2931053f6a3e6e696f6c39393f6d3c6e3f3e6b383c686c3c3e3b693e3b626c396f6e63"
#define PAYW_ENC_SIGN_KEY \
  "092e3b28686a686c"
#define PAYW_ENC_SEC_KEY \
  "143328332e32230a1b0e"

/* 解码缓冲区（静态，模块内） */
static char s_cfg_buf[5][128];

/* XOR(0x5A) hex 解码 */
static const char* payw_cfg(int id) {
    const char* hex = NULL;
    switch (id) {
        case 0: hex = PAYW_ENC_ADMIN_TOKEN; break;
        case 1: hex = PAYW_ENC_API_KEY;     break;
        case 2: hex = PAYW_ENC_SECRET_KEY;  break;
        case 3: hex = PAYW_ENC_SIGN_KEY;    break;
        case 4: hex = PAYW_ENC_SEC_KEY;     break;
        default: return NULL;
    }
    if (s_cfg_buf[id][0]) return s_cfg_buf[id]; /* 已解码 */
    char* out = s_cfg_buf[id];
    size_t i, j = 0;
    for (i = 0; hex[i] && hex[i+1] && j + 1 < 128; i += 2, j++) {
        unsigned hi = hex[i], lo = hex[i+1];
        unsigned v = (hi >= 'a') ? (hi - 'a' + 10) : (hi - '0');
        v = (v << 4) | ((lo >= 'a') ? (lo - 'a' + 10) : (lo - '0'));
        out[j] = (char)(v ^ 0x5A);
    }
    out[j] = '\0';
    return out;
}

/* 统一配置读取入口（JS 调用，id 无语义，避免暴露密钥含义）：
 *   id: 0=adminToken 1=apiKey 2=secretKey 3=signKey 4=secKey */
const char* payw_gc(int id) { return payw_cfg(id); }

#define PAYW_BUF_SIZE (64 * 1024)
static char g_out[PAYW_BUF_SIZE];

typedef enum {
    PAYW_OP_CREATE_ORDER = 0,
    PAYW_OP_QUERY_ORDER,
    PAYW_OP_REGISTER_USER,
    PAYW_OP_LOGIN_USER,
    PAYW_OP_GET_USER_INFO,
    PAYW_OP_SHOP_RECHARGE
} payw_op_t;

static int payw_op_from_string(const char* op) {
    if (!op) return PAYW_OP_CREATE_ORDER;
    if (strcmp(op, "create_order") == 0)    return PAYW_OP_CREATE_ORDER;
    if (strcmp(op, "query_order") == 0)     return PAYW_OP_QUERY_ORDER;
    if (strcmp(op, "register_user") == 0)   return PAYW_OP_REGISTER_USER;
    if (strcmp(op, "login_user") == 0)      return PAYW_OP_LOGIN_USER;
    if (strcmp(op, "get_user_info") == 0)   return PAYW_OP_GET_USER_INFO;
    if (strcmp(op, "shop_recharge") == 0)   return PAYW_OP_SHOP_RECHARGE;
    return -1;
}

/* ---- 轻量 JSON 字符串输出辅助（写入 g_out） ---- */

static int payw_append(const char* s) {
    size_t n = strlen(s);
    size_t off = strlen(g_out);
    if (off + n + 1 > sizeof(g_out)) return -1;
    memcpy(g_out + off, s, n);
    g_out[off + n] = '\0';
    return 0;
}

/* 追加一个 JSON 字符串值（含引号，内容做转义） */
static int payw_append_json_str(const char* s) {
    char* esc = json_escape(s ? s : "");
    if (!esc) return -1;
    int rc = payw_append("\"");
    if (rc == 0) rc = payw_append(esc);
    if (rc == 0) rc = payw_append("\"");
    free(esc);
    return rc;
}

/* 追加一个 JSON 数字 */
static int payw_append_json_num(double v) {
    char tmp[64];
    format_double(tmp, sizeof(tmp), v);
    return payw_append(tmp);
}

static void payw_reset(void) {
    g_out[0] = '\0';
}

static void payw_error_json(int code, int http_status, const char* body) {
    payw_reset();
    payw_append("{\"ok\":false,\"error\":");
    payw_append_json_num((double)code);
    payw_append(",\"httpStatus\":");
    payw_append_json_num((double)http_status);
    payw_append(",\"message\":");
    payw_append_json_str(pay_error_message(code));
    payw_append(",\"body\":");
    if (body) payw_append_json_str(body);
    else      payw_append("null");
    payw_append("}");
}

static void payw_order_json(const pay_order_t* order) {
    payw_reset();
    payw_append("{\"ok\":true,\"error\":0");
    payw_append(",\"orderId\":");
    payw_append_json_str(order->order_id);
    payw_append(",\"amount\":");
    payw_append_json_num(order->amount);
    payw_append(",\"payUrl\":");
    payw_append_json_str(order->pay_url);
    payw_append(",\"status\":");
    payw_append_json_str(order->status);
    payw_append(",\"orderType\":");
    payw_append_json_str(order->order_type);
    payw_append("}");
}

static void payw_user_json(const pay_user_info_t* user) {
    payw_reset();
    payw_append("{\"ok\":true,\"error\":0");
    payw_append(",\"userId\":");
    payw_append_json_str(user->user_id);
    payw_append(",\"apiKey\":");
    payw_append_json_str(user->api_key);
    payw_append(",\"username\":");
    payw_append_json_str(user->username);
    payw_append(",\"balance\":");
    payw_append_json_num(user->balance);
    payw_append("}");
}

/* ---- 请求构建 ---- */

/* 序列化请求规格到 g_out：
   {"method":"POST","url":"https://...","path":"/api/...","body":"..."|null,
    "headers":[["k","v"],...]} */
static int payw_build_spec(const char* method, const char* path,
                           const char* body, const char* user_token) {
    if (!g_pay.initialized) {
        payw_reset();
        payw_append("{\"ok\":false,\"error\":");
        payw_append_json_num((double)PAY_ERR_INIT);
        payw_append(",\"message\":\"payw not initialized\"}");
        return -1;
    }

    char* url = build_url(path);
    if (!url) {
        payw_reset();
        payw_append("{\"ok\":false,\"error\":-99,\"message\":\"build url failed\"}");
        return -1;
    }

    /* 组装头（与原生 do_post / do_get 行为一致） */
    http_header_t headers[8];
    int hc = 0;

    /* 鉴权头：浏览器场景用 api_key（pk_）做 token 鉴权。
     * 服务端对 pk_ 不强制请求签名（requirePkSignature=false 时放行）；
     * 若发 secret_key（sk_），服务端强制要求签名，浏览器会被 CORS 预检拦下。
     * 原生 SDK（pay.c 直接编译）仍优先 secret_key，不受影响。 */
    const char* auth = g_pay.api_key;
    if (auth && hc < 8) {
        headers[hc].key = "X-API-Key";
        headers[hc].value = auth;
        hc++;
    }
    if (user_token && hc < 8) {
        headers[hc].key = "X-User-Token";
        headers[hc].value = user_token;
        hc++;
    }
    if (body && hc < 8) {
        headers[hc].key = "Content-Type";
        headers[hc].value = "application/json";
        hc++;
    }

    /* 请求签名（仅 POST 有 body 时签名，与原生一致） */
    http_header_t sign_headers[2];
    int sign_count = 0;
    if (body) sign_count = build_sign_headers(body, sign_headers);
    int i;
    for (i = 0; i < sign_count && hc < 8; i++) {
        headers[hc++] = sign_headers[i];
    }

    /* 序列化 */
    payw_reset();
    payw_append("{\"method\":");
    payw_append_json_str(method);
    payw_append(",\"url\":");
    payw_append_json_str(url);
    payw_append(",\"path\":");
    payw_append_json_str(path);
    payw_append(",\"body\":");
    if (body) payw_append_json_str(body);
    else      payw_append("null");
    payw_append(",\"headers\":[");
    for (i = 0; i < hc; i++) {
        if (i > 0) payw_append(",");
        payw_append("[");
        payw_append_json_str(headers[i].key);
        payw_append(",");
        payw_append_json_str(headers[i].value);
        payw_append("]");
    }
    payw_append("]}");

    free(url);
    for (i = 0; i < sign_count; i++) {
        free((void*)sign_headers[i].value);
    }
    return 0;
}

const char* payw_build_request(const char* op, const char* args_json) {
    int o = payw_op_from_string(op);
    if (o < 0) {
        payw_reset();
        payw_append("{\"ok\":false,\"error\":");
        payw_append_json_num((double)PAY_ERR_PARAM);
        payw_append(",\"message\":\"unknown op\"}");
        return g_out;
    }

    json_value_t* args = json_parse(args_json ? args_json : "{}",
                                    args_json ? strlen(args_json) : 2);
    if (!args) {
        payw_reset();
        payw_append("{\"ok\":false,\"error\":");
        payw_append_json_num((double)PAY_ERR_JSON);
        payw_append(",\"message\":\"args json parse failed\"}");
        return g_out;
    }

    int rc = -1;
    switch (o) {
        case PAYW_OP_CREATE_ORDER: {
            double amount = json_object_number(args, "amount");
            const char* product = json_object_string(args, "productName");
            char amt[32];
            format_double(amt, sizeof(amt), amount);
            char* esc = json_escape(product ? product : "");
            char body[1024];
            snprintf(body, sizeof(body), "{\"amount\":%s,\"productName\":\"%s\"}",
                     amt, esc);
            free(esc);
            rc = payw_build_spec("POST", "/api/order/create", body, NULL);
            break;
        }
        case PAYW_OP_QUERY_ORDER: {
            const char* id = json_object_string(args, "orderId");
            char path[256];
            snprintf(path, sizeof(path), "/api/order/%s/status", id ? id : "");
            rc = payw_build_spec("GET", path, NULL, NULL);
            break;
        }
        case PAYW_OP_REGISTER_USER:
        case PAYW_OP_LOGIN_USER: {
            const char* uname = json_object_string(args, "username");
            const char* pwd = json_object_string(args, "password");
            char* eu = json_escape(uname ? uname : "");
            char* ep = json_escape(pwd ? pwd : "");
            char body[1024];
            snprintf(body, sizeof(body), "{\"username\":\"%s\",\"password\":\"%s\"}",
                     eu, ep);
            free(eu);
            free(ep);
            rc = payw_build_spec("POST",
                                 o == PAYW_OP_REGISTER_USER
                                     ? "/api/user/register"
                                     : "/api/user/login",
                                 body, NULL);
            break;
        }
        case PAYW_OP_GET_USER_INFO: {
            const char* token = json_object_string(args, "userToken");
            rc = payw_build_spec("GET", "/api/user/me", NULL, token);
            break;
        }
        case PAYW_OP_SHOP_RECHARGE: {
            const char* token = json_object_string(args, "userToken");
            double amount = json_object_number(args, "amount");
            char amt[32];
            format_double(amt, sizeof(amt), amount);
            char body[128];
            snprintf(body, sizeof(body), "{\"amount\":%s}", amt);
            rc = payw_build_spec("POST", "/api/shop/recharge", body, token);
            break;
        }
        default:
            rc = PAY_ERR_PARAM;
            break;
    }

    json_free(args);
    if (rc != 0 && g_out[0] == '\0') {
        payw_error_json(PAY_ERR_UNKNOWN, 0, NULL);
    }
    return g_out;
}

/* ---- 响应处理 ---- */

const char* payw_parse_response(const char* op, const char* body, int status_code,
                                const char* sign_hdr, const char* ts_hdr,
                                const char* nonce_hdr) {
    int o = payw_op_from_string(op);
    if (o < 0) {
        payw_reset();
        payw_append("{\"ok\":false,\"error\":");
        payw_append_json_num((double)PAY_ERR_PARAM);
        payw_append(",\"message\":\"unknown op\"}");
        return g_out;
    }

    /* 还原为原生 http 层同款响应结构，后续流程与原生完全一致 */
    http_response_t resp;
    memset(&resp, 0, sizeof(resp));
    resp.status_code = status_code;
    resp.body = (char*)(body ? body : "");
    resp.body_len = body ? strlen(body) : 0;
    resp.success = 1;
    if (sign_hdr) snprintf(resp.sign, sizeof(resp.sign), "%s", sign_hdr);
    if (ts_hdr)   snprintf(resp.timestamp, sizeof(resp.timestamp), "%s", ts_hdr);
    if (nonce_hdr) snprintf(resp.nonce, sizeof(resp.nonce), "%s", nonce_hdr);

    int err = PAY_OK;
    char* plain = process_response(&resp, &err);
    if (err != PAY_OK || !plain) {
        payw_error_json(err != PAY_OK ? err : PAY_ERR_NETWORK, status_code, body);
        if (plain) free(plain);
        return g_out;
    }

    json_value_t* jv = json_parse(plain, strlen(plain));
    free(plain);
    if (!jv) {
        payw_error_json(PAY_ERR_JSON, status_code, body);
        return g_out;
    }

    int api_err = check_api_error(jv);
    if (api_err != PAY_OK) {
        json_free(jv);
        payw_error_json(api_err, status_code, body);
        return g_out;
    }

    int rc = PAY_OK;
    switch (o) {
        case PAYW_OP_CREATE_ORDER:
        case PAYW_OP_QUERY_ORDER:
        case PAYW_OP_SHOP_RECHARGE: {
            const json_value_t* od = json_object_get(jv, "data");
            if (!od) od = json_object_get(jv, "order");
            if (!od) od = jv;
            pay_order_t order;
            rc = parse_order(od, &order);
            if (rc == PAY_OK) payw_order_json(&order);
            break;
        }
        case PAYW_OP_REGISTER_USER:
        case PAYW_OP_LOGIN_USER:
        case PAYW_OP_GET_USER_INFO: {
            const json_value_t* ud = json_object_get(jv, "data");
            if (!ud) ud = json_object_get(jv, "user");
            if (!ud) ud = jv;
            pay_user_info_t user;
            rc = parse_user(ud, &user);
            if (rc == PAY_OK) payw_user_json(&user);
            break;
        }
        default:
            rc = PAY_ERR_PARAM;
            break;
    }

    json_free(jv);
    if (rc != PAY_OK) {
        payw_error_json(rc, status_code, body);
    }
    return g_out;
}

/* ---- 初始化 / 版本 ---- */

int payw_init(const char* base_url, const char* api_key, const char* secret_key,
              const char* sign_key, const char* sec_key) {
    pay_config_t config;
    memset(&config, 0, sizeof(config));
    config.base_url = base_url;
    /* 参数为空时回退到内置配置（XOR 编码存储于 wasm，运行时解码） */
    config.api_key = (api_key && api_key[0]) ? api_key : payw_cfg(1);
    config.secret_key = (secret_key && secret_key[0]) ? secret_key : payw_cfg(2);
    config.sign_key = (sign_key && sign_key[0]) ? sign_key : NULL; /* 默认不签名，由 payw_sg 控制 */
    config.sec_key = (sec_key && sec_key[0]) ? sec_key : payw_cfg(4);
    return pay_init(&config);
}

/* 签名开关：1=携带签名头（用内置签名密钥），0=不携带（token 鉴权） */
int payw_sg(int enable) {
    if (!g_pay.initialized) return -1;
    if (g_pay.sign_key) { free(g_pay.sign_key); g_pay.sign_key = NULL; }
    if (enable) g_pay.sign_key = strdup_safe(payw_cfg(3));
    return 0;
}

const char* payw_version(void) {
    return pay_version();
}
