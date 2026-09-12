/*
 * Minimal JSON parser for PAY SDK
 * DOM-style: parse entire document into a tree, then query
 */
#ifndef JSON_H
#define JSON_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    JSON_NULL,
    JSON_BOOL,
    JSON_NUMBER,
    JSON_STRING,
    JSON_ARRAY,
    JSON_OBJECT
} json_type_t;

typedef struct json_value json_value_t;

struct json_value {
    json_type_t type;
    union {
        int boolean;
        double number;
        struct { char* data; size_t len; } string;
        struct { json_value_t** items; size_t count; } array;
        struct { char** keys; size_t* key_lens; json_value_t** values; size_t count; } object;
    } u;
};

/* Parse a JSON string. Returns NULL on error. */
json_value_t* json_parse(const char* str, size_t len);

/* Free a parsed JSON value tree */
void json_free(json_value_t* v);

/* Accessors */
json_type_t json_type(const json_value_t* v);
const json_value_t* json_object_get(const json_value_t* obj, const char* key);
const json_value_t* json_array_get(const json_value_t* arr, size_t index);
size_t json_array_size(const json_value_t* arr);

/* Type-specific getters (return defaults if type doesn't match) */
const char*  json_as_string(const json_value_t* v);  /* returns NULL if not string */
double       json_as_number(const json_value_t* v);   /* returns 0.0 if not number */
int          json_as_bool(const json_value_t* v);     /* returns 0 if not bool */
const char*  json_object_string(const json_value_t* obj, const char* key); /* convenience */
double       json_object_number(const json_value_t* obj, const char* key);  /* convenience */

#ifdef __cplusplus
}
#endif

#endif /* JSON_H */
