/*
 * Minimal JSON parser for PAY SDK
 * DOM-style recursive descent parser
 */
#include "json.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef struct {
    const char* data;
    size_t len;
    size_t pos;
} parser_t;

static json_value_t* parse_value(parser_t* p);

static void skip_ws(parser_t* p) {
    while (p->pos < p->len) {
        char c = p->data[p->pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
            p->pos++;
        else
            break;
    }
}

static json_value_t* new_value(json_type_t type) {
    json_value_t* v = (json_value_t*)calloc(1, sizeof(json_value_t));
    if (v) v->type = type;
    return v;
}

static char* decode_string(parser_t* p, size_t* out_len) {
    /* Assumes p->data[p->pos] == '"' */
    p->pos++; /* skip opening quote */
    size_t start = p->pos;
    /* First pass: find end and calculate decoded length */
    size_t decoded_len = 0;
    while (p->pos < p->len && p->data[p->pos] != '"') {
        if (p->data[p->pos] == '\\') {
            p->pos++;
            if (p->pos >= p->len) return NULL;
            switch (p->data[p->pos]) {
                case 'u': p->pos += 4; decoded_len += 4; break; /* worst case 4 bytes UTF-8 */
                default: decoded_len++; break;
            }
            p->pos++;
        } else {
            decoded_len++;
            p->pos++;
        }
    }
    if (p->pos >= p->len) return NULL; /* unterminated string */
    /* p->data[p->pos] == '"' */
    p->pos++; /* skip closing quote */

    /* Second pass: decode */
    char* result = (char*)malloc(decoded_len + 1);
    if (!result) return NULL;
    size_t j = 0;
    size_t i;
    for (i = start; i < p->pos - 1; i++) {
        if (p->data[i] == '\\') {
            i++;
            switch (p->data[i]) {
                case '"':  result[j++] = '"'; break;
                case '\\': result[j++] = '\\'; break;
                case '/':  result[j++] = '/'; break;
                case 'b':  result[j++] = '\b'; break;
                case 'f':  result[j++] = '\f'; break;
                case 'n':  result[j++] = '\n'; break;
                case 'r':  result[j++] = '\r'; break;
                case 't':  result[j++] = '\t'; break;
                case 'u': {
                    /* Decode \uXXXX (basic BMP, no surrogate pairs) */
                    unsigned int cp = 0;
                    int k;
                    for (k = 0; k < 4 && i + 1 < p->pos - 1; k++) {
                        i++;
                        char hc = p->data[i];
                        cp <<= 4;
                        if (hc >= '0' && hc <= '9') cp |= hc - '0';
                        else if (hc >= 'a' && hc <= 'f') cp |= hc - 'a' + 10;
                        else if (hc >= 'A' && hc <= 'F') cp |= hc - 'A' + 10;
                    }
                    /* Encode as UTF-8 */
                    if (cp < 0x80) {
                        result[j++] = (char)cp;
                    } else if (cp < 0x800) {
                        result[j++] = (char)(0xC0 | (cp >> 6));
                        result[j++] = (char)(0x80 | (cp & 0x3F));
                    } else {
                        result[j++] = (char)(0xE0 | (cp >> 12));
                        result[j++] = (char)(0x80 | ((cp >> 6) & 0x3F));
                        result[j++] = (char)(0x80 | (cp & 0x3F));
                    }
                    break;
                }
                default: result[j++] = p->data[i]; break;
            }
        } else {
            result[j++] = p->data[i];
        }
    }
    result[j] = '\0';
    if (out_len) *out_len = j;
    return result;
}

static json_value_t* parse_string(parser_t* p) {
    size_t len = 0;
    char* s = decode_string(p, &len);
    if (!s) return NULL;
    json_value_t* v = new_value(JSON_STRING);
    if (!v) { free(s); return NULL; }
    v->u.string.data = s;
    v->u.string.len = len;
    return v;
}

static json_value_t* parse_number(parser_t* p) {
    size_t start = p->pos;
    if (p->pos < p->len && (p->data[p->pos] == '-' || p->data[p->pos] == '+'))
        p->pos++;
    while (p->pos < p->len && (isdigit((unsigned char)p->data[p->pos]) ||
           p->data[p->pos] == '.' || p->data[p->pos] == 'e' || p->data[p->pos] == 'E' ||
           p->data[p->pos] == '+' || p->data[p->pos] == '-'))
        p->pos++;

    /* Copy and parse */
    size_t slen = p->pos - start;
    char* tmp = (char*)malloc(slen + 1);
    if (!tmp) return NULL;
    memcpy(tmp, p->data + start, slen);
    tmp[slen] = '\0';

    json_value_t* v = new_value(JSON_NUMBER);
    if (!v) { free(tmp); return NULL; }
    v->u.number = strtod(tmp, NULL);
    free(tmp);
    return v;
}

static json_value_t* parse_literal(parser_t* p, const char* lit, json_type_t type) {
    size_t litlen = strlen(lit);
    if (p->pos + litlen > p->len) return NULL;
    if (memcmp(p->data + p->pos, lit, litlen) != 0) return NULL;
    p->pos += litlen;
    json_value_t* v = new_value(type);
    if (!v) return NULL;
    if (type == JSON_BOOL) v->u.boolean = (lit[0] == 't');
    return v;
}

static json_value_t* parse_array(parser_t* p) {
    p->pos++; /* skip '[' */
    json_value_t* v = new_value(JSON_ARRAY);
    if (!v) return NULL;

    skip_ws(p);
    if (p->pos < p->len && p->data[p->pos] == ']') {
        p->pos++;
        return v; /* empty array */
    }

    size_t capacity = 4;
    v->u.array.items = (json_value_t**)malloc(capacity * sizeof(json_value_t*));
    if (!v->u.array.items) { free(v); return NULL; }

    while (1) {
        skip_ws(p);
        json_value_t* item = parse_value(p);
        if (!item) { json_free(v); return NULL; }

        if (v->u.array.count >= capacity) {
            capacity *= 2;
            json_value_t** tmp = (json_value_t**)realloc(v->u.array.items, capacity * sizeof(json_value_t*));
            if (!tmp) { json_free(item); json_free(v); return NULL; }
            v->u.array.items = tmp;
        }
        v->u.array.items[v->u.array.count++] = item;

        skip_ws(p);
        if (p->pos >= p->len) { json_free(v); return NULL; }
        if (p->data[p->pos] == ']') { p->pos++; break; }
        if (p->data[p->pos] != ',') { json_free(v); return NULL; }
        p->pos++; /* skip ',' */
    }

    return v;
}

static json_value_t* parse_object(parser_t* p) {
    p->pos++; /* skip '{' */
    json_value_t* v = new_value(JSON_OBJECT);
    if (!v) return NULL;

    skip_ws(p);
    if (p->pos < p->len && p->data[p->pos] == '}') {
        p->pos++;
        return v; /* empty object */
    }

    size_t capacity = 4;
    v->u.object.keys = (char**)malloc(capacity * sizeof(char*));
    v->u.object.key_lens = (size_t*)malloc(capacity * sizeof(size_t));
    v->u.object.values = (json_value_t**)malloc(capacity * sizeof(json_value_t*));
    if (!v->u.object.keys || !v->u.object.key_lens || !v->u.object.values) {
        json_free(v);
        return NULL;
    }

    while (1) {
        skip_ws(p);
        if (p->pos >= p->len || p->data[p->pos] != '"') { json_free(v); return NULL; }

        size_t klen = 0;
        char* key = decode_string(p, &klen);
        if (!key) { json_free(v); return NULL; }

        skip_ws(p);
        if (p->pos >= p->len || p->data[p->pos] != ':') { free(key); json_free(v); return NULL; }
        p->pos++; /* skip ':' */

        skip_ws(p);
        json_value_t* val = parse_value(p);
        if (!val) { free(key); json_free(v); return NULL; }

        if (v->u.object.count >= capacity) {
            capacity *= 2;
            char** tk = (char**)realloc(v->u.object.keys, capacity * sizeof(char*));
            size_t* tl = (size_t*)realloc(v->u.object.key_lens, capacity * sizeof(size_t));
            json_value_t** tv = (json_value_t**)realloc(v->u.object.values, capacity * sizeof(json_value_t*));
            if (!tk || !tl || !tv) {
                free(key); json_free(val); json_free(v); return NULL;
            }
            v->u.object.keys = tk;
            v->u.object.key_lens = tl;
            v->u.object.values = tv;
        }

        v->u.object.keys[v->u.object.count] = key;
        v->u.object.key_lens[v->u.object.count] = klen;
        v->u.object.values[v->u.object.count] = val;
        v->u.object.count++;

        skip_ws(p);
        if (p->pos >= p->len) { json_free(v); return NULL; }
        if (p->data[p->pos] == '}') { p->pos++; break; }
        if (p->data[p->pos] != ',') { json_free(v); return NULL; }
        p->pos++; /* skip ',' */
    }

    return v;
}

static json_value_t* parse_value(parser_t* p) {
    skip_ws(p);
    if (p->pos >= p->len) return NULL;

    char c = p->data[p->pos];
    switch (c) {
        case '"':  return parse_string(p);
        case '{':  return parse_object(p);
        case '[':  return parse_array(p);
        case 't':  return parse_literal(p, "true", JSON_BOOL);
        case 'f':  return parse_literal(p, "false", JSON_BOOL);
        case 'n':  return parse_literal(p, "null", JSON_NULL);
        default:
            if (c == '-' || c == '+' || (c >= '0' && c <= '9'))
                return parse_number(p);
            return NULL;
    }
}

json_value_t* json_parse(const char* str, size_t len) {
    if (!str || len == 0) return NULL;
    parser_t p = { str, len, 0 };
    json_value_t* v = parse_value(&p);
    if (!v) return NULL;
    skip_ws(&p);
    /* Allow trailing whitespace but not trailing garbage */
    return v;
}

void json_free(json_value_t* v) {
    if (!v) return;
    switch (v->type) {
        case JSON_STRING:
            free(v->u.string.data);
            break;
        case JSON_ARRAY: {
            size_t i;
            for (i = 0; i < v->u.array.count; i++)
                json_free(v->u.array.items[i]);
            free(v->u.array.items);
            break;
        }
        case JSON_OBJECT: {
            size_t i;
            for (i = 0; i < v->u.object.count; i++) {
                free(v->u.object.keys[i]);
                json_free(v->u.object.values[i]);
            }
            free(v->u.object.keys);
            free(v->u.object.key_lens);
            free(v->u.object.values);
            break;
        }
        default:
            break;
    }
    free(v);
}

json_type_t json_type(const json_value_t* v) {
    return v ? v->type : JSON_NULL;
}

const json_value_t* json_object_get(const json_value_t* obj, const char* key) {
    if (!obj || obj->type != JSON_OBJECT || !key) return NULL;
    size_t i;
    size_t klen = strlen(key);
    for (i = 0; i < obj->u.object.count; i++) {
        if (obj->u.object.key_lens[i] == klen &&
            memcmp(obj->u.object.keys[i], key, klen) == 0)
            return obj->u.object.values[i];
    }
    return NULL;
}

const json_value_t* json_array_get(const json_value_t* arr, size_t index) {
    if (!arr || arr->type != JSON_ARRAY) return NULL;
    if (index >= arr->u.array.count) return NULL;
    return arr->u.array.items[index];
}

size_t json_array_size(const json_value_t* arr) {
    if (!arr || arr->type != JSON_ARRAY) return 0;
    return arr->u.array.count;
}

const char* json_as_string(const json_value_t* v) {
    if (!v || v->type != JSON_STRING) return NULL;
    return v->u.string.data;
}

double json_as_number(const json_value_t* v) {
    if (!v || v->type != JSON_NUMBER) return 0.0;
    return v->u.number;
}

int json_as_bool(const json_value_t* v) {
    if (!v || v->type != JSON_BOOL) return 0;
    return v->u.boolean;
}

const char* json_object_string(const json_value_t* obj, const char* key) {
    return json_as_string(json_object_get(obj, key));
}

double json_object_number(const json_value_t* obj, const char* key) {
    return json_as_number(json_object_get(obj, key));
}
