/*
 * HTTP client implementation
 * - Windows: WinHTTP (zero external dependency)
 * - Linux/macOS: libcurl
 */
#include "http.h"
#include <stdlib.h>
#include <string.h>

/* ========================================================================== */
/*  Platform: Windows (WinHTTP)                                               */
/* ========================================================================== */
#ifdef _WIN32

#include <windows.h>
#include <winhttp.h>
#include <stdio.h>

#pragma comment(lib, "winhttp.lib")

/* Convert UTF-8 to wide string. Caller must free. */
static wchar_t* utf8_to_wide(const char* utf8) {
    if (!utf8) return NULL;
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    if (len <= 0) return NULL;
    wchar_t* wide = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (!wide) return NULL;
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, wide, len);
    return wide;
}

/* Convert wide string to UTF-8. Caller must free. */
static char* wide_to_utf8(const wchar_t* wide) {
    if (!wide) return NULL;
    int len = WideCharToMultiByte(CP_UTF8, 0, wide, -1, NULL, 0, NULL, NULL);
    if (len <= 0) return NULL;
    char* utf8 = (char*)malloc(len);
    if (!utf8) return NULL;
    WideCharToMultiByte(CP_UTF8, 0, wide, -1, utf8, len, NULL, NULL);
    return utf8;
}

/* Callback context for reading response body */
typedef struct {
    char*  data;
    size_t size;
    size_t capacity;
} body_accumulator_t;

static void body_accumulator_init(body_accumulator_t* acc) {
    acc->capacity = 4096;
    acc->size = 0;
    acc->data = (char*)malloc(acc->capacity);
    if (acc->data) acc->data[0] = '\0';
}

static int body_accumulator_append(body_accumulator_t* acc, const void* data, size_t len) {
    if (!acc->data) return -1;
    if (acc->size + len + 1 > acc->capacity) {
        size_t new_cap = acc->capacity;
        while (new_cap < acc->size + len + 1) new_cap *= 2;
        char* tmp = (char*)realloc(acc->data, new_cap);
        if (!tmp) return -1;
        acc->data = tmp;
        acc->capacity = new_cap;
    }
    memcpy(acc->data + acc->size, data, len);
    acc->size += len;
    acc->data[acc->size] = '\0';
    return 0;
}

static void body_accumulator_free(body_accumulator_t* acc) {
    if (acc->data) {
        free(acc->data);
        acc->data = NULL;
    }
}

static void extract_response_header(HINTERNET hRequest, http_response_t* resp) {
    DWORD buf_size;
    DWORD index = 0;

    /* Try to get X-API-Sign */
    const wchar_t* headers_to_check[] = {
        L"X-API-Sign",
        L"X-API-Timestamp",
        L"X-API-Nonce"
    };
    char* targets[] = {
        resp->sign,
        resp->timestamp,
        resp->nonce
    };
    size_t target_sizes[] = {
        sizeof(resp->sign),
        sizeof(resp->timestamp),
        sizeof(resp->nonce)
    };
    int i;

    for (i = 0; i < 3; i++) {
        buf_size = 0;
        index = 0;
        WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_CUSTOM,
                            (LPWSTR)headers_to_check[i],
                            WINHTTP_NO_OUTPUT_BUFFER, &buf_size, &index);
        if (buf_size > 0 && GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
            wchar_t* wbuf = (wchar_t*)malloc(buf_size);
            if (wbuf) {
                index = 0;
                if (WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_CUSTOM,
                                        (LPWSTR)headers_to_check[i],
                                        wbuf, &buf_size, &index)) {
                    char* utf8 = wide_to_utf8(wbuf);
                    if (utf8) {
                        strncpy(targets[i], utf8, target_sizes[i] - 1);
                        targets[i][target_sizes[i] - 1] = '\0';
                        free(utf8);
                    }
                }
                free(wbuf);
            }
        }
        /* Reset index for next header */
        index = 0;
    }
}

http_response_t* http_request(const char* method, const char* url,
                              const char* body, const char* content_type,
                              http_header_t* headers, int header_count) {
    http_response_t* resp = (http_response_t*)calloc(1, sizeof(http_response_t));
    if (!resp) return NULL;

    /* Parse URL using WinHttpCrackUrl */
    URL_COMPONENTS uc;
    memset(&uc, 0, sizeof(uc));
    uc.dwStructSize = sizeof(uc);

    wchar_t host_buf[256] = {0};
    wchar_t path_buf[1024] = {0};
    uc.lpszHostName = host_buf;
    uc.dwHostNameLength = 255;
    uc.lpszUrlPath = path_buf;
    uc.dwUrlPathLength = 1023;

    wchar_t* wurl = utf8_to_wide(url);
    if (!wurl) {
        strncpy(resp->error, "URL conversion failed", sizeof(resp->error) - 1);
        return resp;
    }

    if (!WinHttpCrackUrl(wurl, 0, 0, &uc)) {
        free(wurl);
        snprintf(resp->error, sizeof(resp->error), "URL parse failed: %lu", GetLastError());
        return resp;
    }
    free(wurl);

    /* Create session */
    HINTERNET hSession = WinHttpOpen(L"PaySDK-C/1.0",
                                     WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                                     WINHTTP_NO_PROXY_NAME,
                                     WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hSession) {
        snprintf(resp->error, sizeof(resp->error), "WinHttpOpen failed: %lu", GetLastError());
        return resp;
    }

    /* Create connection */
    HINTERNET hConnect = WinHttpConnect(hSession, uc.lpszHostName,
                                        uc.nPort == 0 ? INTERNET_DEFAULT_HTTPS_PORT : uc.nPort, 0);
    if (!hConnect) {
        snprintf(resp->error, sizeof(resp->error), "WinHttpConnect failed: %lu", GetLastError());
        WinHttpCloseHandle(hSession);
        return resp;
    }

    /* Create request */
    DWORD flags = (uc.nScheme == INTERNET_SCHEME_HTTPS) ? WINHTTP_FLAG_SECURE : 0;
    wchar_t* wmethod = utf8_to_wide(method);
    HINTERNET hRequest = WinHttpOpenRequest(hConnect,
                                            wmethod ? wmethod : L"GET",
                                            uc.lpszUrlPath,
                                            NULL,
                                            WINHTTP_NO_REFERER,
                                            WINHTTP_DEFAULT_ACCEPT_TYPES,
                                            flags);
    if (wmethod) free(wmethod);
    if (!hRequest) {
        snprintf(resp->error, sizeof(resp->error), "WinHttpOpenRequest failed: %lu", GetLastError());
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return resp;
    }

    /* Build headers string */
    /* Estimate size: content-type + extra headers + user-agent */
    size_t hdr_cap = 1024;
    int i;
    for (i = 0; i < header_count; i++) {
        hdr_cap += strlen(headers[i].key) + strlen(headers[i].value) + 4;
    }
    char* hdr_str = (char*)malloc(hdr_cap);
    if (!hdr_str) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        strncpy(resp->error, "alloc failed", sizeof(resp->error) - 1);
        return resp;
    }
    hdr_str[0] = '\0';

    if (content_type) {
        strcat(hdr_str, "Content-Type: ");
        strcat(hdr_str, content_type);
        strcat(hdr_str, "\r\n");
    }
    for (i = 0; i < header_count; i++) {
        strcat(hdr_str, headers[i].key);
        strcat(hdr_str, ": ");
        strcat(hdr_str, headers[i].value);
        strcat(hdr_str, "\r\n");
    }

    /* Convert headers to wide and add */
    if (hdr_str[0]) {
        wchar_t* whdr = utf8_to_wide(hdr_str);
        if (whdr) {
            WinHttpAddRequestHeaders(hRequest, whdr, (DWORD)-1,
                                     WINHTTP_ADDREQ_FLAG_ADD | WINHTTP_ADDREQ_FLAG_REPLACE);
            free(whdr);
        }
    }
    free(hdr_str);

    /* Send request */
    size_t body_len = (body) ? strlen(body) : 0;
    BOOL bResult = WinHttpSendRequest(hRequest,
                                      WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                                      (LPVOID)body, (DWORD)body_len,
                                      (DWORD)body_len, 0);
    if (!bResult) {
        snprintf(resp->error, sizeof(resp->error), "WinHttpSendRequest failed: %lu", GetLastError());
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return resp;
    }

    /* Receive response */
    if (!WinHttpReceiveResponse(hRequest, NULL)) {
        snprintf(resp->error, sizeof(resp->error), "WinHttpReceiveResponse failed: %lu", GetLastError());
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return resp;
    }

    /* Query status code */
    DWORD status_code = 0;
    DWORD status_size = sizeof(status_code);
    WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX, &status_code, &status_size, WINHTTP_NO_HEADER_INDEX);
    resp->status_code = (int)status_code;

    /* Extract special response headers */
    extract_response_header(hRequest, resp);

    /* Read body */
    body_accumulator_t acc;
    body_accumulator_init(&acc);

    DWORD bytes_available = 0;
    DWORD bytes_read = 0;
    char read_buf[8192];

    while (WinHttpQueryDataAvailable(hRequest, &bytes_available) && bytes_available > 0) {
        DWORD to_read = (bytes_available < sizeof(read_buf)) ? bytes_available : (DWORD)sizeof(read_buf);
        if (WinHttpReadData(hRequest, read_buf, to_read, &bytes_read) && bytes_read > 0) {
            if (body_accumulator_append(&acc, read_buf, bytes_read) != 0) {
                break;
            }
        } else {
            break;
        }
    }

    resp->body = acc.data;
    resp->body_len = acc.size;
    resp->success = 1;

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);

    return resp;
}

/* ========================================================================== */
/*  Platform: Linux/macOS (libcurl)                                           */
/* ========================================================================== */
#else /* !_WIN32 */

#include <curl/curl.h>
#include <stdio.h>

typedef struct {
    char*  data;
    size_t size;
    size_t capacity;
} curl_body_t;

static size_t write_cb(void* contents, size_t size, size_t nmemb, void* userp) {
    curl_body_t* buf = (curl_body_t*)userp;
    size_t realsize = size * nmemb;

    if (buf->size + realsize + 1 > buf->capacity) {
        size_t new_cap = buf->capacity;
        while (new_cap < buf->size + realsize + 1) new_cap *= 2;
        char* tmp = (char*)realloc(buf->data, new_cap);
        if (!tmp) return 0;
        buf->data = tmp;
        buf->capacity = new_cap;
    }

    memcpy(buf->data + buf->size, contents, realsize);
    buf->size += realsize;
    buf->data[buf->size] = '\0';
    return realsize;
}

static size_t header_cb(char* buffer, size_t size, size_t nitems, void* userp) {
    http_response_t* resp = (http_response_t*)userp;
    size_t total = size * nitems;

    /* Check for X-API-Sign */
    if (total > 10 && strncasecmp(buffer, "X-API-Sign:", 11) == 0) {
        size_t val_start = 11;
        while (val_start < total && (buffer[val_start] == ' ' || buffer[val_start] == '\t')) val_start++;
        size_t val_len = total - val_start;
        while (val_len > 0 && (buffer[val_start + val_len - 1] == '\r' || buffer[val_start + val_len - 1] == '\n')) val_len--;
        size_t copy_len = val_len < sizeof(resp->sign) - 1 ? val_len : sizeof(resp->sign) - 1;
        memcpy(resp->sign, buffer + val_start, copy_len);
        resp->sign[copy_len] = '\0';
    } else if (total > 16 && strncasecmp(buffer, "X-API-Timestamp:", 16) == 0) {
        size_t val_start = 16;
        while (val_start < total && (buffer[val_start] == ' ' || buffer[val_start] == '\t')) val_start++;
        size_t val_len = total - val_start;
        while (val_len > 0 && (buffer[val_start + val_len - 1] == '\r' || buffer[val_start + val_len - 1] == '\n')) val_len--;
        size_t copy_len = val_len < sizeof(resp->timestamp) - 1 ? val_len : sizeof(resp->timestamp) - 1;
        memcpy(resp->timestamp, buffer + val_start, copy_len);
        resp->timestamp[copy_len] = '\0';
    } else if (total > 13 && strncasecmp(buffer, "X-API-Nonce:", 12) == 0) {
        size_t val_start = 12;
        while (val_start < total && (buffer[val_start] == ' ' || buffer[val_start] == '\t')) val_start++;
        size_t val_len = total - val_start;
        while (val_len > 0 && (buffer[val_start + val_len - 1] == '\r' || buffer[val_start + val_len - 1] == '\n')) val_len--;
        size_t copy_len = val_len < sizeof(resp->nonce) - 1 ? val_len : sizeof(resp->nonce) - 1;
        memcpy(resp->nonce, buffer + val_start, copy_len);
        resp->nonce[copy_len] = '\0';
    }

    return total;
}

http_response_t* http_request(const char* method, const char* url,
                              const char* body, const char* content_type,
                              http_header_t* headers, int header_count) {
    http_response_t* resp = (http_response_t*)calloc(1, sizeof(http_response_t));
    if (!resp) return NULL;

    CURL* curl = curl_easy_init();
    if (!curl) {
        strncpy(resp->error, "curl_easy_init failed", sizeof(resp->error) - 1);
        return resp;
    }

    curl_body_t cbody = { NULL, 0, 4096 };
    cbody.data = (char*)malloc(cbody.capacity);
    if (!cbody.data) {
        curl_easy_cleanup(curl);
        strncpy(resp->error, "alloc failed", sizeof(resp->error) - 1);
        return resp;
    }
    cbody.data[0] = '\0';

    struct curl_slist* hdr_list = NULL;
    char ct_header[256];
    if (content_type) {
        snprintf(ct_header, sizeof(ct_header), "Content-Type: %s", content_type);
        hdr_list = curl_slist_append(hdr_list, ct_header);
    }

    int i;
    for (i = 0; i < header_count; i++) {
        char hdr_line[1024];
        snprintf(hdr_line, sizeof(hdr_line), "%s: %s", headers[i].key, headers[i].value);
        hdr_list = curl_slist_append(hdr_list, hdr_line);
    }

    /* Always set User-Agent to avoid Cloudflare Bot Fight Mode */
    hdr_list = curl_slist_append(hdr_list, "User-Agent: PaySDK-C/1.0");

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdr_list);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &cbody);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, header_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, resp);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);

    if (strcmp(method, "POST") == 0) {
        curl_easy_setopt(curl, CURLOPT_POST, 1L);
        if (body) {
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)strlen(body));
        }
    }

    CURLcode res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
        snprintf(resp->error, sizeof(resp->error), "curl: %s", curl_easy_strerror(res));
    } else {
        long http_code = 0;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
        resp->status_code = (int)http_code;
        resp->body = cbody.data;
        resp->body_len = cbody.size;
        resp->success = 1;
        cbody.data = NULL; /* transferred ownership */
    }

    if (cbody.data) free(cbody.data);
    curl_slist_free_all(hdr_list);
    curl_easy_cleanup(curl);

    return resp;
}

#endif /* _WIN32 */

void http_response_free(http_response_t* resp) {
    if (!resp) return;
    if (resp->body) free(resp->body);
    free(resp);
}
