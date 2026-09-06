/*
** obf_util.h - Obfuscation module utilities
** Shared by all C obfuscation modules
*/
#ifndef OBF_UTIL_H
#define OBF_UTIL_H

#include "luac.h"

/*===========================================================================
** Random (xorshift32, seedable)
**=========================================================================*/
void obf_srand(unsigned int seed);
unsigned int obf_rand(void);
int obf_rand_range(int lo, int hi);  /* [lo, hi] inclusive */

/*===========================================================================
** XOR encrypt/decrypt (str_encrypt v2 format: key_byte + xor_data)
**=========================================================================*/
char *obf_xor_encrypt(const char *s, size_t len, size_t *out_len);
char *obf_xor_decrypt(const char *s, size_t len, size_t *out_len);

/*===========================================================================
** Code array manipulation
**=========================================================================*/

/* Insert n instructions at pos (1-based) into p->code */
void obf_code_insert(luac_Proto *p, int pos, const unsigned int *ins, int n);

/* Remove n instructions at pos (1-based) from p->code */
void obf_code_remove(luac_Proto *p, int pos, int n);

/* Adjust jump offsets after inserting n instructions at pos */
void obf_adjust_jumps_insert(unsigned int *code, int code_len, int pos, int n);

/* Adjust jump offsets after removing n instructions at pos */
void obf_adjust_jumps_remove(unsigned int *code, int code_len, int pos, int n);

/* Invalidate cached Lua code table (call after any p->code modification) */
void obf_invalidate_code_cache(lua_State *L, luac_Proto *p);

/* Invalidate all cached Lua tables (code, k, p, lineinfo, etc.) */
void obf_invalidate_all_caches(lua_State *L, luac_Proto *p);


/*===========================================================================
** Proto helpers
**=========================================================================*/

/* Recursively visit all protos (pre-order: parent then children) */
typedef void (*obf_proto_visitor)(luac_Proto *p, void *ud);
void obf_visit_protos(luac_Proto *p, obf_proto_visitor fn, void *ud);

/* Recursively visit all protos (post-order: children then parent) */
void obf_visit_protos_post(luac_Proto *p, obf_proto_visitor fn, void *ud);

/* Compile Lua source to a proto (uses string.dump + undump internally) */
int obf_compile_subproto(lua_State *L, const char *src, luac_Proto **out);

/* Add a sub-proto to p, returns its 0-based index */
int obf_add_subproto(lua_State *L, luac_Proto *p, luac_Proto *sub);

/* Add a string constant to p->k, returns 0-based index */
int obf_add_k_string(luac_Proto *p, const char *s, size_t len);

/* Add a number constant to p->k, returns 0-based index */
int obf_add_k_number(luac_Proto *p, double num);

/* Add an integer constant (LUA_TNUMINT) to p->k, returns 0-based index */
int obf_add_k_integer(luac_Proto *p, long long num);

/* Add a nil constant to p->k, returns 0-based index */
int obf_add_k_nil(luac_Proto *p);

/* Ensure maxstacksize is at least n */
void obf_ensure_stack(luac_Proto *p, int n);

/*===========================================================================
** Decrypt proto detection (for str_encrypt reverse)
**=========================================================================*/
int obf_is_decrypt_proto(luac_Proto *p);

/*===========================================================================
** Lua helper: get proto from stack arg 1, options table from arg 2
**=========================================================================*/
luac_Proto *obf_check_proto(lua_State *L);

#endif /* OBF_UTIL_H */
