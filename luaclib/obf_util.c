/*
** obf_util.c - Obfuscation module utilities implementation
*/
#include "obf_util.h"

/*===========================================================================
** Random (xorshift32)
**=========================================================================*/
static unsigned int g_rand_state = 2463534242u;
static int g_rand_seeded = 0;

void obf_srand(unsigned int seed) {
    if (!g_rand_seeded) {
        g_rand_state = seed ? seed : 2463534242u;
        g_rand_seeded = 1;
    }
}

void obf_srand_force(unsigned int seed) {
    g_rand_state = seed ? seed : 2463534242u;
    g_rand_seeded = 1;
}

unsigned int obf_rand(void) {
    g_rand_state ^= g_rand_state << 13;
    g_rand_state ^= g_rand_state >> 17;
    g_rand_state ^= g_rand_state << 5;
    return g_rand_state;
}

int obf_rand_range(int lo, int hi) {
    if (hi <= lo) return lo;
    return lo + (int)(obf_rand() % (unsigned int)(hi - lo + 1));
}

/*===========================================================================
** XOR encrypt/decrypt
**=========================================================================*/
char *obf_xor_encrypt(const char *s, size_t len, size_t *out_len) {
    unsigned char key = (unsigned char)(1 + (obf_rand() % 255));
    char *r = luac_alloc(len + 1);
    r[0] = (char)key;
    for (size_t i = 0; i < len; i++)
        r[i + 1] = (char)((unsigned char)s[i] ^ key);
    if (out_len) *out_len = len + 1;
    return r;
}

char *obf_xor_decrypt(const char *s, size_t len, size_t *out_len) {
    if (len < 1) {
        if (out_len) *out_len = 0;
        return luac_alloc(1);
    }
    unsigned char key = (unsigned char)s[0];
    size_t outlen = len - 1;
    char *r = luac_alloc(outlen + 1);
    for (size_t i = 0; i < outlen; i++)
        r[i] = (char)((unsigned char)s[i + 1] ^ key);
    r[outlen] = '\0';
    if (out_len) *out_len = outlen;
    return r;
}

/*===========================================================================
** Jump adjustment
**=========================================================================*/
static int is_jump_op(int op) {
    return op == 30 || op == 39 || op == 40 || op == 42;
}

void obf_adjust_jumps_insert(unsigned int *code, int code_len, int pos, int n) {
    int pos0 = pos - 1;
    for (int i = 0; i < code_len; i++) {
        /* skip newly injected instructions (they didn't exist before insertion) */
        if (i >= pos0 && i < pos0 + n) continue;
        if (is_jump_op(code[i] & 0x3F)) {
            int sbx = (int)(code[i] >> 14) - 131071;
            /* compute OLD index: jumps at/after insertion point shifted by n */
            int old_i = (i >= pos0) ? i - n : i;
            int target_old = old_i + sbx + 1;
            int delta = 0;
            if (old_i < pos0 && target_old >= pos0) delta = n;
            else if (old_i >= pos0 && target_old < pos0) delta = -n;
            if (delta) code[i] = (code[i] & 0x3FFF) | ((unsigned int)(sbx + delta + 131071) << 14);
        }
    }
}

void obf_adjust_jumps_remove(unsigned int *code, int code_len, int pos, int n) {
    int pos0 = pos - 1;
    for (int i = 0; i < code_len; i++) {
        if (is_jump_op(code[i] & 0x3F)) {
            int sbx = (int)(code[i] >> 14) - 131071;
            /* compute OLD index before removal: jumps at/after pos0 were at i+n */
            int old_i = (i >= pos0) ? i + n : i;
            int target_old = old_i + sbx + 1;
            int delta = 0;
            if (old_i < pos0 && target_old > pos0) delta = -n;
            else if (old_i > pos0 && target_old < pos0) delta = n;
            if (delta) code[i] = (code[i] & 0x3FFF) | ((unsigned int)(sbx + delta + 131071) << 14);
        }
    }
}

/* Insert n instructions at pos (1-based) into p->code, adjust jumps */
void obf_code_insert(luac_Proto *p, int pos, const unsigned int *ins, int n) {
    int pos0 = pos - 1;
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + n));
    memmove(&p->code[pos0 + n], &p->code[pos0], sizeof(unsigned int) * (p->sizecode - pos0));
    memcpy(&p->code[pos0], ins, sizeof(unsigned int) * n);
    p->sizecode += n;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos, n);
}

/* Remove n instructions at pos (1-based) from p->code, adjust jumps */
void obf_code_remove(luac_Proto *p, int pos, int n) {
    int pos0 = pos - 1;
    memmove(&p->code[pos0], &p->code[pos0 + n], sizeof(unsigned int) * (p->sizecode - pos0 - n));
    p->sizecode -= n;
    p->code = realloc(p->code, sizeof(unsigned int) * p->sizecode);
    obf_adjust_jumps_remove(p->code, p->sizecode, pos, n);
}

/*===========================================================================
** Proto traversal
**=========================================================================*/
void obf_visit_protos(luac_Proto *p, obf_proto_visitor fn, void *ud) {
    fn(p, ud);
    if (p->p) for (int i = 0; i < p->sizep; i++) obf_visit_protos(p->p[i], fn, ud);
}

static void visit_post(luac_Proto *p, obf_proto_visitor fn, void *ud) {
    if (p->p) for (int i = 0; i < p->sizep; i++) visit_post(p->p[i], fn, ud);
    fn(p, ud);
}

void obf_visit_protos_post(luac_Proto *p, obf_proto_visitor fn, void *ud) {
    visit_post(p, fn, ud);
}

/*===========================================================================
** Compile Lua source and return FIRST sub-proto (raw struct, not userdata).
** Source must be: return function(...) ... end
** The raw struct is detached from the main proto; caller owns it.
**=========================================================================*/
int obf_compile_subproto(lua_State *L, const char *src, luac_Proto **out) {
    int top = lua_gettop(L);

    if (luaL_loadstring(L, src) != LUA_OK) {
        lua_settop(L, top); return 0;
    }

    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dump");
    if(!lua_isfunction(L,-1)){/*OCS_DBG*/ fprintf(stderr,"[OCS] string.dump NOT function\n");lua_settop(L,top);return 0;}
    lua_pushvalue(L, -3);
    lua_call(L, 1, 1);

    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dec");
    if (lua_isfunction(L, -1)) {
        lua_pushvalue(L, -3);
        lua_call(L, 1, 1);
        lua_replace(L, -3);
        lua_pop(L, 1);
    } else {
        lua_pop(L, 2);
    }

    lua_getglobal(L, "luac");
    if(!lua_istable(L,-1)){/*OCS_DBG*/ fprintf(stderr,"[OCS] luac NOT table\n");lua_settop(L,top);return 0;}
    lua_getfield(L, -1, "undump");
    if(!lua_isfunction(L,-1)){/*OCS_DBG*/ fprintf(stderr,"[OCS] luac.undump NOT function\n");lua_settop(L,top);return 0;}
    lua_pushvalue(L, -3);
    lua_pushboolean(L, 0);
    lua_call(L, 2, 1);

    luac_Proto *main_p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");
    luac_Proto *sub_raw = NULL;
    if (main_p->p && main_p->sizep >= 1) sub_raw = main_p->p[0];
    if (!sub_raw) { lua_settop(L, top); return 0; }

    if (sub_raw->upval_instack && sub_raw->sizeupvalues > 0) {
        sub_raw->upval_instack[0] = 0;
        sub_raw->upval_idx[0] = 0;
    }

    main_p->p[0] = NULL;
    main_p->sizep = 0;
    lua_settop(L, top);
    *out = sub_raw;
    return 1;
}

/*===========================================================================
** Add sub-proto (raw struct) to parent. Creates userdata from raw struct.
**=========================================================================*/
int obf_add_subproto(lua_State *L, luac_Proto *p, luac_Proto *sub_raw) {
    int idx = p->sizep;
    p->p = realloc(p->p, sizeof(luac_Proto *) * (p->sizep + 1));

    /* If p table doesn't exist yet, create it and populate with all existing
       sub-protos. This ensures all sub-proto userdata are referenced by Lua
       and won't be GC'd, preventing dangling pointers in p->p[]. */
    if (p->p_tbl == LUA_NOREF) {
        lua_newtable(L);
        for (int i = 0; i < idx; i++) {
            luac_push_proto(L, p->p[i]);
            luac_Proto *ud = (luac_Proto *)lua_touserdata(L, -1);
            p->p[i] = ud;
            lua_rawseti(L, -2, i + 1);
        }
        p->p_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    luac_push_proto(L, sub_raw);
    luac_Proto *sub_ud = (luac_Proto *)lua_touserdata(L, -1);
    p->p[idx] = sub_ud;
    p->sizep++;

    lua_rawgeti(L, LUA_REGISTRYINDEX, p->p_tbl);
    lua_pushvalue(L, -2);
    lua_rawseti(L, -2, idx + 1);
    lua_pop(L, 1);
    lua_pop(L, 1);
    return idx;
}

/*===========================================================================
** Constant helpers
**=========================================================================*/
static void grow_k(luac_Proto *p) {
    p->k_tag = realloc(p->k_tag, sizeof(int) * (p->sizek + 1));
    p->k_str = realloc(p->k_str, sizeof(char *) * (p->sizek + 1));
    p->k_str_len = realloc(p->k_str_len, sizeof(int) * (p->sizek + 1));
    p->k_num = realloc(p->k_num, sizeof(double) * (p->sizek + 1));
    p->k_int = realloc(p->k_int, sizeof(int64_t) * (p->sizek + 1));
    p->k_bool = realloc(p->k_bool, sizeof(int) * (p->sizek + 1));
}

int obf_add_k_string(luac_Proto *p, const char *s, size_t len) {
    int idx = p->sizek;
    grow_k(p);
    p->k_tag[idx] = (len <= 40) ? LUA_TSHRSTR : LUA_TLNGSTR;
    p->k_str[idx] = luac_strndup(s, len);
    p->k_str_len[idx] = (int)len;
    p->k_num[idx] = 0; p->k_bool[idx] = 0;
    p->sizek++;
    return idx;
}

int obf_add_k_number(luac_Proto *p, double num) {
    int idx = p->sizek;
    grow_k(p);
    p->k_tag[idx] = LUA_TNUMFLT;
    p->k_str[idx] = NULL; p->k_str_len[idx] = 0;
    p->k_num[idx] = num; p->k_int[idx] = 0; p->k_bool[idx] = 0;
    p->sizek++;
    return idx;
}

int obf_add_k_integer(luac_Proto *p, long long num) {
    int idx = p->sizek;
    grow_k(p);
    p->k_tag[idx] = LUA_TNUMINT;
    p->k_str[idx] = NULL; p->k_str_len[idx] = 0;
    p->k_num[idx] = (double)num; p->k_int[idx] = num; p->k_bool[idx] = 0;
    p->sizek++;
    return idx;
}

int obf_add_k_nil(luac_Proto *p) {
    int idx = p->sizek;
    grow_k(p);
    p->k_tag[idx] = LUA_TNIL;
    p->k_str[idx] = NULL; p->k_str_len[idx] = 0;
    p->k_num[idx] = 0; p->k_bool[idx] = 0;
    p->sizek++;
    return idx;
}

void obf_ensure_stack(luac_Proto *p, int n) {
    if (p->maxstacksize < (unsigned char)n) p->maxstacksize = (unsigned char)n;
}

/*===========================================================================
** Decrypt proto detection
**=========================================================================*/
int obf_is_decrypt_proto(luac_Proto *p) {
    if (!p->k_str || !p->code) return 0;
    int has_byte = 0, has_char = 0, has_loop = 0, has_bxor = 0;
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TSHRSTR || p->k_tag[i] == LUA_TLNGSTR) && p->k_str[i]) {
            if (strcmp(p->k_str[i], "byte") == 0) has_byte = 1;
            if (strcmp(p->k_str[i], "char") == 0) has_char = 1;
        }
    }
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_BXOR) has_bxor = 1;
        if (op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP) has_loop = 1;
    }
    return has_byte && has_char && (has_bxor || has_loop);
}

/*===========================================================================
** Lua helper
**=========================================================================*/
/*===========================================================================
** Cache invalidation (cached Lua tables in registry must be invalidated
** whenever the underlying C arrays are modified)
**=========================================================================*/
static void unref_table(lua_State *L, int *ref) {
    if (*ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, *ref);
        *ref = LUA_NOREF;
    }
}

void obf_invalidate_code_cache(lua_State *L, luac_Proto *p) {
    unref_table(L, &p->code_tbl);
}

void obf_invalidate_all_caches(lua_State *L, luac_Proto *p) {
    /* NOTE: do NOT invalidate p_tbl here. The p table holds references to
       sub-proto userdata. Invalidating it would allow those userdata to be
       GC'd, freeing their C arrays while p->p[] still points to them
       (dangling pointer). C modules recurse into p->p[] and need the
       sub-proto C structs to stay alive. */
    unref_table(L, &p->code_tbl);
    unref_table(L, &p->k_tbl);
    unref_table(L, &p->lineinfo_tbl);
    unref_table(L, &p->locvars_tbl);
    unref_table(L, &p->upvalues_tbl);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        obf_invalidate_all_caches(L, p->p[i]);
}

luac_Proto *obf_check_proto(lua_State *L) {
    return (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");
}
