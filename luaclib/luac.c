/*
** luac.c - Lua 5.3 bytecode editor library
** Equivalent to com.nwdxlgzs.luac53support Java library
** Supports: undump, dump, Proto editing, Instruction manipulation
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "lua.h"
#include "lauxlib.h"

/*===========================================================================
** Data structures
**=========================================================================*/

typedef struct luac_Proto {
    unsigned int *code;
    struct luac_Proto **p;
    /* constants */
    int *k_tag;
    char **k_str;
    double *k_num;
    int *k_bool;
    /* debug */
    int *lineinfo;
    char **locvar_name;
    int *locvar_startpc;
    int *locvar_endpc;
    char **upval_name;
    unsigned char *upval_instack;
    unsigned char *upval_idx;
    /* sizes */
    int sizecode, sizep, sizek;
    int sizelineinfo, sizelocvars, sizeupvalues;
    /* header */
    int numparams;
    unsigned char is_vararg;
    unsigned char maxstacksize;
    int linedefined;
    int lastlinedefined;
    char *source;
    /* cached Lua tables (registry refs) */
    int code_tbl, p_tbl, k_tbl;
    int lineinfo_tbl, locvars_tbl, upvalues_tbl;
} luac_Proto;

/* constant tags (matching Lua 5.3) */
#define LUA_TNIL      0
#define LUA_TBOOLEAN  1
#define LUA_TNUMFLT   3
#define LUA_TNUMINT   19  /* variant tag */
#define LUA_TSHRSTR   4
#define LUA_TLNGSTR   20

/*===========================================================================
** Memory helpers
**=========================================================================*/

static void *luac_alloc(size_t sz) {
    void *p = calloc(1, sz);
    if (!p) { fprintf(stderr, "luac: out of memory\n"); exit(1); }
    return p;
}

static char *luac_strdup(const char *s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char *p = luac_alloc(len);
    memcpy(p, s, len);
    return p;
}

static void luac_free_proto(luac_Proto *p) {
    if (!p) return;
    int i;
    free(p->code);
    if (p->p) {
        for (i = 0; i < p->sizep; i++) luac_free_proto(p->p[i]);
        free(p->p);
    }
    free(p->k_tag);
    if (p->k_str) {
        for (i = 0; i < p->sizek; i++) free(p->k_str[i]);
        free(p->k_str);
    }
    free(p->k_num);
    free(p->k_bool);
    free(p->lineinfo);
    if (p->locvar_name) {
        for (i = 0; i < p->sizelocvars; i++) free(p->locvar_name[i]);
        free(p->locvar_name);
    }
    free(p->locvar_startpc);
    free(p->locvar_endpc);
    if (p->upval_name) {
        for (i = 0; i < p->sizeupvalues; i++) free(p->upval_name[i]);
        free(p->upval_name);
    }
    free(p->upval_instack);
    free(p->upval_idx);
    free(p->source);
    free(p);
}

/*===========================================================================
** andlua encrypted string decryption (matches lundump.c decrypt_string)
**=========================================================================*/
static void andlua_decrypt_string(unsigned char *buff, size_t len) {
    size_t length = len;
    unsigned char first = (unsigned char)(buff[0] ^ (length % 255));
    size_t step = (size_t)first + len;
    size_t i;
    buff[0] = first;
    for (i = 1; i < len; i++) {
        length += step;
        buff[i] ^= (unsigned char)(length % 255);
    }
}

static int andlua_is_valid_text(const unsigned char *p, size_t len) {
    size_t i = 0;
    if (len == 0) return 1;
    while (i < len) {
        unsigned char c = p[i];
        int need;
        if (c == 0x00) return 0;
        if (c < 0x80) {
            if (c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) return 0;
            if (c == 0x7F) return 0;
            i++;
            continue;
        }
        if (c < 0xC0) return 0;
        if (c < 0xE0) need = 1;
        else if (c < 0xF0) need = 2;
        else if (c < 0xF8) need = 3;
        else return 0;
        if (i + need >= len) return 0;
        for (int j = 1; j <= need; j++) {
            if ((p[i + j] & 0xC0) != 0x80) return 0;
        }
        i += need + 1;
    }
    return 1;
}

/*===========================================================================
** Undump (bytecode -> Proto)
**=========================================================================*/

typedef struct {
    const unsigned char *buf;
    size_t pos;
    size_t len;
    int encrypted;  /* 1 = andlua encrypted strings */
} UndumpState;

static unsigned char LoadByte(UndumpState *S) {
    if (S->pos >= S->len) { fprintf(stderr, "luac: unexpected end\n"); exit(1); }
    return S->buf[S->pos++];
}

static int LoadInt(UndumpState *S) {
    int v = 0;
    for (int i = 0; i < 4; i++) v |= ((int)LoadByte(S)) << (i * 8);
    return v;
}

static unsigned int LoadInstruction(UndumpState *S) {
    unsigned int v = 0;
    for (int i = 0; i < 4; i++) v |= ((unsigned int)LoadByte(S)) << (i * 8);
    return v;
}

static double LoadNumber(UndumpState *S) {
    unsigned char buf[8];
    for (int i = 0; i < 8; i++) buf[i] = LoadByte(S);
    double v;
    memcpy(&v, buf, 8);
    return v;
}

static long long LoadInteger(UndumpState *S) {
    unsigned char buf[8];
    for (int i = 0; i < 8; i++) buf[i] = LoadByte(S);
    long long v;
    memcpy(&v, buf, 8);
    return v;
}

static char *LoadString(UndumpState *S) {
    size_t size = LoadByte(S);
    if (size == 0xFF) {
        size = 0;
        for (int i = 0; i < 4; i++) size |= ((size_t)LoadByte(S)) << (i * 8);
    }
    if (size == 0) return NULL;
    size_t len = size - 1;  /* size includes null terminator, but only len bytes stored */
    char *s = luac_alloc(size);
    for (size_t i = 0; i < len; i++) s[i] = (char)LoadByte(S);
    s[len] = '\0';
    /* andlua: always try to decrypt strings (matches andlua original behavior).
       If decrypted text is valid, use it; otherwise keep original (plaintext). */
    if (len > 0) {
        unsigned char *tmp = luac_alloc(len);
        memcpy(tmp, s, len);
        andlua_decrypt_string(tmp, len);
        if (andlua_is_valid_text(tmp, len)) {
            memcpy(s, tmp, len);
        }
        free(tmp);
    }
    return s;
}

static void LoadCode(UndumpState *S, luac_Proto *f) {
    f->sizecode = LoadInt(S);
    if (f->sizecode > 0) {
        f->code = luac_alloc(sizeof(unsigned int) * f->sizecode);
        for (int i = 0; i < f->sizecode; i++) f->code[i] = LoadInstruction(S);
    }
}

static void LoadConstants(UndumpState *S, luac_Proto *f) {
    f->sizek = LoadInt(S);
    if (f->sizek > 0) {
        f->k_tag = luac_alloc(sizeof(int) * f->sizek);
        f->k_str = luac_alloc(sizeof(char *) * f->sizek);
        f->k_num = luac_alloc(sizeof(double) * f->sizek);
        f->k_bool = luac_alloc(sizeof(int) * f->sizek);
        for (int i = 0; i < f->sizek; i++) {
            int t = LoadByte(S);
            f->k_tag[i] = t;
            f->k_str[i] = NULL;
            f->k_num[i] = 0;
            f->k_bool[i] = 0;
            switch (t) {
                case LUA_TNIL: break;
                case LUA_TBOOLEAN: f->k_bool[i] = LoadByte(S); break;
                case LUA_TNUMFLT: f->k_num[i] = LoadNumber(S); break;
                case LUA_TNUMINT: f->k_num[i] = (double)LoadInteger(S); break;
                case LUA_TSHRSTR:
                case LUA_TLNGSTR: f->k_str[i] = LoadString(S); break;
                default:
                    /* 未知常量 tag（混淆注入的垃圾），当作 nil 处理，不读取数据 */
                    fprintf(stderr, "luac: warning: unknown constant tag %d at index %d, treating as nil\n", t, i);
                    f->k_tag[i] = LUA_TNIL;
                    break;
            }
        }
    }
}

static void LoadProtos(UndumpState *S, luac_Proto *f);

static void LoadUpvalues(UndumpState *S, luac_Proto *f) {
    f->sizeupvalues = LoadInt(S);
    if (f->sizeupvalues > 0) {
        f->upval_instack = luac_alloc(sizeof(unsigned char) * f->sizeupvalues);
        f->upval_idx = luac_alloc(sizeof(unsigned char) * f->sizeupvalues);
        f->upval_name = luac_alloc(sizeof(char *) * f->sizeupvalues);
        for (int i = 0; i < f->sizeupvalues; i++) {
            f->upval_instack[i] = LoadByte(S);
            f->upval_idx[i] = LoadByte(S);
            f->upval_name[i] = NULL;  /* name loaded in debug section */
        }
    }
}

static void LoadFunction(UndumpState *S, luac_Proto *f) {
    f->source = LoadString(S);
    f->linedefined = LoadInt(S);
    f->lastlinedefined = LoadInt(S);
    f->numparams = LoadByte(S);
    f->is_vararg = LoadByte(S);
    f->maxstacksize = LoadByte(S);
    LoadCode(S, f);
    LoadConstants(S, f);
    LoadUpvalues(S, f);
    LoadProtos(S, f);
    /* debug */
    f->sizelineinfo = LoadInt(S);
    if (f->sizelineinfo > 0) {
        f->lineinfo = luac_alloc(sizeof(int) * f->sizelineinfo);
        for (int i = 0; i < f->sizelineinfo; i++) f->lineinfo[i] = LoadInt(S);
    }
    f->sizelocvars = LoadInt(S);
    if (f->sizelocvars > 0) {
        f->locvar_name = luac_alloc(sizeof(char *) * f->sizelocvars);
        f->locvar_startpc = luac_alloc(sizeof(int) * f->sizelocvars);
        f->locvar_endpc = luac_alloc(sizeof(int) * f->sizelocvars);
        for (int i = 0; i < f->sizelocvars; i++) {
            f->locvar_name[i] = LoadString(S);
            f->locvar_startpc[i] = LoadInt(S);
            f->locvar_endpc[i] = LoadInt(S);
        }
    }
    /* debug upvalues: only names (instack/idx loaded in LoadUpvalues) */
    int n_upval = LoadInt(S);
    for (int i = 0; i < n_upval; i++) {
        if (f->upval_name && i < f->sizeupvalues) {
            free(f->upval_name[i]);
            f->upval_name[i] = LoadString(S);
        } else {
            LoadString(S);  /* skip */
        }
    }
}

static void LoadProtos(UndumpState *S, luac_Proto *f) {
    f->sizep = LoadInt(S);
    if (f->sizep > 0) {
        f->p = luac_alloc(sizeof(luac_Proto *) * f->sizep);
        for (int i = 0; i < f->sizep; i++) {
            f->p[i] = luac_alloc(sizeof(luac_Proto));
            /* Initialize lazy table refs to LUA_NOREF (calloc zeros them to 0,
               which would be mistaken for valid registry refs in sync_all_tables) */
            f->p[i]->code_tbl = LUA_NOREF;
            f->p[i]->k_tbl = LUA_NOREF;
            f->p[i]->p_tbl = LUA_NOREF;
            f->p[i]->lineinfo_tbl = LUA_NOREF;
            f->p[i]->locvars_tbl = LUA_NOREF;
            f->p[i]->upvalues_tbl = LUA_NOREF;
            LoadFunction(S, f->p[i]);
        }
    }
}

static int CheckHeader(UndumpState *S) {
    unsigned char first = S->buf[S->pos];
    if (first == 0x1C) {
        /* andlua encrypted format: skip 0x1C, rest is standard header */
        S->encrypted = 1;
        S->pos++;
    }
    /* signature */
    if (LoadByte(S) != 0x1B) return -1;
    if (LoadByte(S) != 'L') return -1;
    if (LoadByte(S) != 'u') return -1;
    if (LoadByte(S) != 'a') return -1;
    /* version */
    if (LoadByte(S) != 0x53) return -1;
    /* format */
    LoadByte(S);
    /* LUAC_DATA */
    if (LoadByte(S) != 0x19) return -1;
    if (LoadByte(S) != 0x93) return -1;
    if (LoadByte(S) != 0x0D) return -1;
    if (LoadByte(S) != 0x0A) return -1;
    if (LoadByte(S) != 0x1A) return -1;
    if (LoadByte(S) != 0x0A) return -1;
    /* sizes */
    LoadByte(S); /* sizeof(int) */
    LoadByte(S); /* sizeof(size_t) */
    LoadByte(S); /* sizeof(Instruction) */
    LoadByte(S); /* sizeof(lua_Integer) */
    LoadByte(S); /* sizeof(lua_Number) */
    /* LUAC_INT + LUAC_NUM */
    for (int i = 0; i < 16; i++) LoadByte(S);
    return 0;
}

/*===========================================================================
** Dump (Proto -> bytecode)
**=========================================================================*/

typedef struct {
    unsigned char *buf;
    size_t pos;
    size_t cap;
} DumpState;

static void DumpGrow(DumpState *D, size_t need) {
    if (D->pos + need > D->cap) {
        D->cap = (D->pos + need) * 2;
        D->buf = realloc(D->buf, D->cap);
        if (!D->buf) { fprintf(stderr, "luac: out of memory\n"); exit(1); }
    }
}

static void DumpByte(DumpState *D, unsigned char b) {
    DumpGrow(D, 1);
    D->buf[D->pos++] = b;
}

static void DumpInt(DumpState *D, int v) {
    for (int i = 0; i < 4; i++) DumpByte(D, (unsigned char)((v >> (i * 8)) & 0xFF));
}

static void DumpInstruction(DumpState *D, unsigned int v) {
    for (int i = 0; i < 4; i++) DumpByte(D, (unsigned char)((v >> (i * 8)) & 0xFF));
}

static void DumpNumber(DumpState *D, double v) {
    unsigned char buf[8];
    memcpy(buf, &v, 8);
    for (int i = 0; i < 8; i++) DumpByte(D, buf[i]);
}

static void DumpInteger(DumpState *D, long long v) {
    unsigned char buf[8];
    memcpy(buf, &v, 8);
    for (int i = 0; i < 8; i++) DumpByte(D, buf[i]);
}

static void DumpString(DumpState *D, const char *s) {
    if (!s) {
        DumpByte(D, 0);
        return;
    }
    size_t len = strlen(s);
    size_t size = len + 1;  /* size includes null terminator */
    if (size <= 253) {
        DumpByte(D, (unsigned char)size);
    } else {
        DumpByte(D, 0xFF);
        for (int i = 0; i < 4; i++) DumpByte(D, (unsigned char)((size >> (i * 8)) & 0xFF));
    }
    for (size_t i = 0; i < len; i++) DumpByte(D, (unsigned char)s[i]);
    /* null terminator is NOT stored in bytecode */
}

static void DumpCode(DumpState *D, luac_Proto *f) {
    DumpInt(D, f->sizecode);
    for (int i = 0; i < f->sizecode; i++) DumpInstruction(D, f->code[i]);
}

static void DumpConstants(DumpState *D, luac_Proto *f) {
    DumpInt(D, f->sizek);
    for (int i = 0; i < f->sizek; i++) {
        int t = f->k_tag[i];
        DumpByte(D, (unsigned char)t);
        switch (t) {
            case LUA_TNIL: break;
            case LUA_TBOOLEAN: DumpByte(D, (unsigned char)f->k_bool[i]); break;
            case LUA_TNUMFLT: DumpNumber(D, f->k_num[i]); break;
            case LUA_TNUMINT: DumpInteger(D, (long long)f->k_num[i]); break;
            case LUA_TSHRSTR:
            case LUA_TLNGSTR: DumpString(D, f->k_str[i]); break;
        }
    }
}

static void DumpFunction(DumpState *D, luac_Proto *f);

static void DumpProtos(DumpState *D, luac_Proto *f) {
    DumpInt(D, f->sizep);
    for (int i = 0; i < f->sizep; i++) DumpFunction(D, f->p[i]);
}

static void DumpUpvalues(DumpState *D, luac_Proto *f) {
    DumpInt(D, f->sizeupvalues);
    for (int i = 0; i < f->sizeupvalues; i++) {
        DumpByte(D, f->upval_instack[i]);
        DumpByte(D, f->upval_idx[i]);
    }
}

static void DumpFunction(DumpState *D, luac_Proto *f) {
    DumpString(D, f->source);
    DumpInt(D, f->linedefined);
    DumpInt(D, f->lastlinedefined);
    DumpByte(D, (unsigned char)f->numparams);
    DumpByte(D, f->is_vararg);
    DumpByte(D, f->maxstacksize);
    DumpCode(D, f);
    DumpConstants(D, f);
    DumpUpvalues(D, f);
    DumpProtos(D, f);
    /* debug */
    DumpInt(D, f->sizelineinfo);
    for (int i = 0; i < f->sizelineinfo; i++) DumpInt(D, f->lineinfo[i]);
    DumpInt(D, f->sizelocvars);
    for (int i = 0; i < f->sizelocvars; i++) {
        DumpString(D, f->locvar_name[i]);
        DumpInt(D, f->locvar_startpc[i]);
        DumpInt(D, f->locvar_endpc[i]);
    }
    /* debug upvalues: only names */
    DumpInt(D, f->sizeupvalues);
    for (int i = 0; i < f->sizeupvalues; i++) {
        DumpString(D, f->upval_name[i]);
    }
}

static void DumpHeader(DumpState *D) {
    /* signature */
    DumpByte(D, 0x1B);
    DumpByte(D, 'L');
    DumpByte(D, 'u');
    DumpByte(D, 'a');
    /* version 5.3 */
    DumpByte(D, 0x53);
    /* format */
    DumpByte(D, 0x00);
    /* LUAC_DATA */
    DumpByte(D, 0x19);
    DumpByte(D, 0x93);
    DumpByte(D, 0x0D);
    DumpByte(D, 0x0A);
    DumpByte(D, 0x1A);
    DumpByte(D, 0x0A);
    /* sizes */
    DumpByte(D, 4);  /* sizeof(int) */
    DumpByte(D, 4);  /* sizeof(size_t) */
    DumpByte(D, 4);  /* sizeof(Instruction) */
    DumpByte(D, 8);  /* sizeof(lua_Integer) */
    DumpByte(D, 8);  /* sizeof(lua_Number) */
    /* LUAC_INT = 0x5678 */
    DumpInteger(D, 0x5678);
    /* LUAC_NUM = 370.5 */
    DumpNumber(D, 370.5);
}

/*===========================================================================
** Sync: Lua table <-> C struct
**=========================================================================*/

/* Push a constant value onto Lua stack */
static void push_constant(lua_State *L, luac_Proto *f, int idx) {
    switch (f->k_tag[idx]) {
        case LUA_TNIL: lua_pushnil(L); break;
        case LUA_TBOOLEAN: lua_pushboolean(L, f->k_bool[idx]); break;
        case LUA_TNUMFLT: lua_pushnumber(L, f->k_num[idx]); break;
        case LUA_TNUMINT: lua_pushinteger(L, (long long)f->k_num[idx]); break;
        case LUA_TSHRSTR:
        case LUA_TLNGSTR: lua_pushstring(L, f->k_str[idx] ? f->k_str[idx] : ""); break;
        default: lua_pushnil(L); break;
    }
}

/* Create code table from C array */
static void create_code_table(lua_State *L, luac_Proto *f) {
    lua_newtable(L);
    for (int i = 0; i < f->sizecode; i++) {
        lua_pushinteger(L, (lua_Integer)f->code[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

/* Create k table from C array */
static void create_k_table(lua_State *L, luac_Proto *f) {
    lua_newtable(L);
    for (int i = 0; i < f->sizek; i++) {
        push_constant(L, f, i);
        lua_rawseti(L, -2, i + 1);
    }
}

/* Create p table from C array */
static void create_p_table(lua_State *L, luac_Proto *f);

static void create_lineinfo_table(lua_State *L, luac_Proto *f) {
    lua_newtable(L);
    for (int i = 0; i < f->sizelineinfo; i++) {
        lua_pushinteger(L, f->lineinfo[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

static void create_locvars_table(lua_State *L, luac_Proto *f) {
    lua_newtable(L);
    for (int i = 0; i < f->sizelocvars; i++) {
        lua_newtable(L);
        lua_pushstring(L, f->locvar_name[i] ? f->locvar_name[i] : "");
        lua_setfield(L, -2, "varname");
        lua_pushinteger(L, f->locvar_startpc[i]);
        lua_setfield(L, -2, "startpc");
        lua_pushinteger(L, f->locvar_endpc[i]);
        lua_setfield(L, -2, "endpc");
        lua_rawseti(L, -2, i + 1);
    }
}

static void create_upvalues_table(lua_State *L, luac_Proto *f) {
    lua_newtable(L);
    for (int i = 0; i < f->sizeupvalues; i++) {
        lua_newtable(L);
        lua_pushstring(L, f->upval_name[i] ? f->upval_name[i] : "");
        lua_setfield(L, -2, "name");
        lua_pushinteger(L, f->upval_instack[i]);
        lua_setfield(L, -2, "instack");
        lua_pushinteger(L, f->upval_idx[i]);
        lua_setfield(L, -2, "idx");
        lua_rawseti(L, -2, i + 1);
    }
}

/* Push Proto userdata onto stack */
static void push_proto(lua_State *L, luac_Proto *f);

static void create_p_table(lua_State *L, luac_Proto *f) {
    lua_newtable(L);
    for (int i = 0; i < f->sizep; i++) {
        push_proto(L, f->p[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

/* Sync code table back to C */
static void sync_code_from_table(lua_State *L, luac_Proto *f, int tbl_idx) {
    lua_pushvalue(L, tbl_idx);
    int n = (int)lua_rawlen(L, -1);
    free(f->code);
    f->sizecode = n;
    f->code = NULL;
    if (n > 0) {
        f->code = luac_alloc(sizeof(unsigned int) * n);
        for (int i = 0; i < n; i++) {
            lua_rawgeti(L, -1, i + 1);
            f->code[i] = (unsigned int)lua_tointeger(L, -1);
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
}

/* Sync k table back to C */
static void sync_k_from_table(lua_State *L, luac_Proto *f, int tbl_idx) {
    lua_pushvalue(L, tbl_idx);
    int n = (int)lua_rawlen(L, -1);
    /* free old */
    if (f->k_str) {
        for (int i = 0; i < f->sizek; i++) free(f->k_str[i]);
        free(f->k_str);
    }
    free(f->k_tag); free(f->k_num); free(f->k_bool);
    f->sizek = n;
    f->k_tag = NULL; f->k_str = NULL; f->k_num = NULL; f->k_bool = NULL;
    if (n > 0) {
        f->k_tag = luac_alloc(sizeof(int) * n);
        f->k_str = luac_alloc(sizeof(char *) * n);
        f->k_num = luac_alloc(sizeof(double) * n);
        f->k_bool = luac_alloc(sizeof(int) * n);
        for (int i = 0; i < n; i++) {
            lua_rawgeti(L, -1, i + 1);
            int t = lua_type(L, -1);
            f->k_str[i] = NULL;
            f->k_num[i] = 0;
            f->k_bool[i] = 0;
            if (t == LUA_TNIL) {
                f->k_tag[i] = LUA_TNIL;
            } else if (t == LUA_TBOOLEAN) {
                f->k_tag[i] = LUA_TBOOLEAN;
                f->k_bool[i] = lua_toboolean(L, -1);
            } else if (t == LUA_TNUMBER) {
                if (lua_isinteger(L, -1)) {
                    f->k_tag[i] = LUA_TNUMINT;
                } else {
                    f->k_tag[i] = LUA_TNUMFLT;
                }
                f->k_num[i] = lua_tonumber(L, -1);
            } else if (t == LUA_TSTRING) {
                const char *s = lua_tostring(L, -1);
                f->k_tag[i] = (strlen(s) <= 40) ? LUA_TSHRSTR : LUA_TLNGSTR;
                f->k_str[i] = luac_strdup(s);
            } else if (t == LUA_TTABLE) {
                /* poison constant: {__poison = tag} writes raw tag byte only,
                   matching andlua VM behavior (unknown tags read no data) */
                lua_getfield(L, -1, "__poison");
                if (lua_isnumber(L, -1)) {
                    f->k_tag[i] = (int)lua_tointeger(L, -1);
                } else {
                    f->k_tag[i] = LUA_TNIL;
                }
                lua_pop(L, 1);
            } else {
                f->k_tag[i] = LUA_TNIL;
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
}

/* Sync p table back to C */
static void sync_p_from_table(lua_State *L, luac_Proto *f, int tbl_idx) {
    lua_pushvalue(L, tbl_idx);
    int n = (int)lua_rawlen(L, -1);
    /* Save old pointers to check for duplicates (do NOT free them;
       they are owned by Lua userdata objects still referenced in the table) */
    luac_Proto **old_p = f->p;
    int old_sizep = f->sizep;
    f->sizep = n;
    f->p = NULL;
    if (n > 0) {
        f->p = luac_alloc(sizeof(luac_Proto *) * n);
        for (int i = 0; i < n; i++) {
            lua_rawgeti(L, -1, i + 1);
            luac_Proto *sub = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");
            f->p[i] = sub;
            lua_pop(L, 1);
        }
    }
    /* Only free old protos that are not referenced in the new p array */
    if (old_p) {
        for (int i = 0; i < old_sizep; i++) {
            int still_referenced = 0;
            for (int j = 0; j < n; j++) {
                if (f->p[j] == old_p[i]) { still_referenced = 1; break; }
            }
            if (!still_referenced) luac_free_proto(old_p[i]);
        }
        free(old_p);
    }
    lua_pop(L, 1);
}

static void sync_lineinfo_from_table(lua_State *L, luac_Proto *f, int tbl_idx) {
    lua_pushvalue(L, tbl_idx);
    int n = (int)lua_rawlen(L, -1);
    free(f->lineinfo);
    f->sizelineinfo = n;
    f->lineinfo = NULL;
    if (n > 0) {
        f->lineinfo = luac_alloc(sizeof(int) * n);
        for (int i = 0; i < n; i++) {
            lua_rawgeti(L, -1, i + 1);
            f->lineinfo[i] = (int)lua_tointeger(L, -1);
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
}

static void sync_locvars_from_table(lua_State *L, luac_Proto *f, int tbl_idx) {
    lua_pushvalue(L, tbl_idx);
    int n = (int)lua_rawlen(L, -1);
    if (f->locvar_name) {
        for (int i = 0; i < f->sizelocvars; i++) free(f->locvar_name[i]);
        free(f->locvar_name);
    }
    free(f->locvar_startpc); free(f->locvar_endpc);
    f->sizelocvars = n;
    f->locvar_name = NULL; f->locvar_startpc = NULL; f->locvar_endpc = NULL;
    if (n > 0) {
        f->locvar_name = luac_alloc(sizeof(char *) * n);
        f->locvar_startpc = luac_alloc(sizeof(int) * n);
        f->locvar_endpc = luac_alloc(sizeof(int) * n);
        for (int i = 0; i < n; i++) {
            lua_rawgeti(L, -1, i + 1);
            lua_getfield(L, -1, "varname");
            f->locvar_name[i] = luac_strdup(lua_tostring(L, -1));
            lua_pop(L, 1);
            lua_getfield(L, -1, "startpc");
            f->locvar_startpc[i] = (int)lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_getfield(L, -1, "endpc");
            f->locvar_endpc[i] = (int)lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
}

static void sync_upvalues_from_table(lua_State *L, luac_Proto *f, int tbl_idx) {
    lua_pushvalue(L, tbl_idx);
    int n = (int)lua_rawlen(L, -1);
    if (f->upval_name) {
        for (int i = 0; i < f->sizeupvalues; i++) free(f->upval_name[i]);
        free(f->upval_name);
    }
    free(f->upval_instack); free(f->upval_idx);
    f->sizeupvalues = n;
    f->upval_name = NULL; f->upval_instack = NULL; f->upval_idx = NULL;
    if (n > 0) {
        f->upval_name = luac_alloc(sizeof(char *) * n);
        f->upval_instack = luac_alloc(sizeof(unsigned char) * n);
        f->upval_idx = luac_alloc(sizeof(unsigned char) * n);
        for (int i = 0; i < n; i++) {
            lua_rawgeti(L, -1, i + 1);
            lua_getfield(L, -1, "name");
            f->upval_name[i] = luac_strdup(lua_tostring(L, -1));
            lua_pop(L, 1);
            lua_getfield(L, -1, "instack");
            f->upval_instack[i] = (unsigned char)lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_getfield(L, -1, "idx");
            f->upval_idx[i] = (unsigned char)lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
}

/* Sync all tables back to C before dump */
static void sync_all_tables(lua_State *L, luac_Proto *f) {
    if (f->code_tbl != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->code_tbl);
        sync_code_from_table(L, f, -1);
        lua_pop(L, 1);
    }
    if (f->k_tbl != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->k_tbl);
        sync_k_from_table(L, f, -1);
        lua_pop(L, 1);
    }
    if (f->p_tbl != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->p_tbl);
        sync_p_from_table(L, f, -1);
        lua_pop(L, 1);
    }
    if (f->lineinfo_tbl != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->lineinfo_tbl);
        sync_lineinfo_from_table(L, f, -1);
        lua_pop(L, 1);
    }
    if (f->locvars_tbl != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->locvars_tbl);
        sync_locvars_from_table(L, f, -1);
        lua_pop(L, 1);
    }
    if (f->upvalues_tbl != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->upvalues_tbl);
        sync_upvalues_from_table(L, f, -1);
        lua_pop(L, 1);
    }
    /* recursively sync sub protos */
    for (int i = 0; i < f->sizep; i++) {
        sync_all_tables(L, f->p[i]);
    }
}

/*===========================================================================
** Proto userdata
**=========================================================================*/

static int proto_gc(lua_State *L) {
    luac_Proto *f = (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");
    if (f->code_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->code_tbl);
    if (f->p_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->p_tbl);
    if (f->k_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->k_tbl);
    if (f->lineinfo_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->lineinfo_tbl);
    if (f->locvars_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->locvars_tbl);
    if (f->upvalues_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->upvalues_tbl);
    /* Note: do NOT free f here if sub-protos are referenced by p table;
       but since p table holds the userdata, GC handles them independently.
       However, our C struct still owns the arrays. Free only the top-level
       arrays that are NOT shared with sub-proto userdata.
       Sub-protos in f->p are separate userdata with their own GC. */
    free(f->code);
    free(f->k_tag);
    if (f->k_str) {
        for (int i = 0; i < f->sizek; i++) free(f->k_str[i]);
        free(f->k_str);
    }
    free(f->k_num); free(f->k_bool);
    free(f->lineinfo);
    if (f->locvar_name) {
        for (int i = 0; i < f->sizelocvars; i++) free(f->locvar_name[i]);
        free(f->locvar_name);
    }
    free(f->locvar_startpc); free(f->locvar_endpc);
    if (f->upval_name) {
        for (int i = 0; i < f->sizeupvalues; i++) free(f->upval_name[i]);
        free(f->upval_name);
    }
    free(f->upval_instack); free(f->upval_idx);
    free(f->source);
    /* f->p contains pointers to sub-proto C structs, but those are owned
       by their own userdata. We just free the pointer array. */
    free(f->p);
    return 0;
}

static int proto_index(lua_State *L) {
    luac_Proto *f = (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");
    const char *key = luaL_checkstring(L, 2);

    if (strcmp(key, "code") == 0) {
        if (f->code_tbl == LUA_NOREF) {
            create_code_table(L, f);
            f->code_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->code_tbl);
        return 1;
    }
    if (strcmp(key, "k") == 0) {
        if (f->k_tbl == LUA_NOREF) {
            create_k_table(L, f);
            f->k_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->k_tbl);
        return 1;
    }
    if (strcmp(key, "p") == 0) {
        if (f->p_tbl == LUA_NOREF) {
            create_p_table(L, f);
            f->p_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->p_tbl);
        return 1;
    }
    if (strcmp(key, "lineinfo") == 0) {
        if (f->lineinfo_tbl == LUA_NOREF) {
            create_lineinfo_table(L, f);
            f->lineinfo_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->lineinfo_tbl);
        return 1;
    }
    if (strcmp(key, "locvars") == 0) {
        if (f->locvars_tbl == LUA_NOREF) {
            create_locvars_table(L, f);
            f->locvars_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->locvars_tbl);
        return 1;
    }
    if (strcmp(key, "upvalues") == 0) {
        if (f->upvalues_tbl == LUA_NOREF) {
            create_upvalues_table(L, f);
            f->upvalues_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, f->upvalues_tbl);
        return 1;
    }
    if (strcmp(key, "sizecode") == 0) { lua_pushinteger(L, f->sizecode); return 1; }
    if (strcmp(key, "sizek") == 0) { lua_pushinteger(L, f->sizek); return 1; }
    if (strcmp(key, "sizep") == 0) { lua_pushinteger(L, f->sizep); return 1; }
    if (strcmp(key, "sizelineinfo") == 0) { lua_pushinteger(L, f->sizelineinfo); return 1; }
    if (strcmp(key, "sizelocvars") == 0) { lua_pushinteger(L, f->sizelocvars); return 1; }
    if (strcmp(key, "sizeupvalues") == 0) { lua_pushinteger(L, f->sizeupvalues); return 1; }
    if (strcmp(key, "numparams") == 0) { lua_pushinteger(L, f->numparams); return 1; }
    if (strcmp(key, "is_vararg") == 0) { lua_pushinteger(L, f->is_vararg); return 1; }
    if (strcmp(key, "maxstacksize") == 0) { lua_pushinteger(L, f->maxstacksize); return 1; }
    if (strcmp(key, "linedefined") == 0) { lua_pushinteger(L, f->linedefined); return 1; }
    if (strcmp(key, "lastlinedefined") == 0) { lua_pushinteger(L, f->lastlinedefined); return 1; }
    if (strcmp(key, "source") == 0) { lua_pushstring(L, f->source ? f->source : ""); return 1; }

    lua_pushnil(L);
    return 1;
}

static int proto_newindex(lua_State *L) {
    luac_Proto *f = (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");
    const char *key = luaL_checkstring(L, 2);

    if (strcmp(key, "numparams") == 0) { f->numparams = (int)luaL_checkinteger(L, 3); return 0; }
    if (strcmp(key, "is_vararg") == 0) { f->is_vararg = (unsigned char)luaL_checkinteger(L, 3); return 0; }
    if (strcmp(key, "maxstacksize") == 0) { f->maxstacksize = (unsigned char)luaL_checkinteger(L, 3); return 0; }
    if (strcmp(key, "linedefined") == 0) { f->linedefined = (int)luaL_checkinteger(L, 3); return 0; }
    if (strcmp(key, "lastlinedefined") == 0) { f->lastlinedefined = (int)luaL_checkinteger(L, 3); return 0; }
    if (strcmp(key, "source") == 0) {
        free(f->source);
        f->source = luac_strdup(luaL_checkstring(L, 3));
        return 0;
    }
    /* code/k/p/lineinfo/locvars/upvalues are table references;
       replacing them means updating the cached table */
    if (strcmp(key, "code") == 0) {
        luaL_checktype(L, 3, LUA_TTABLE);
        if (f->code_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->code_tbl);
        lua_pushvalue(L, 3);
        f->code_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        return 0;
    }
    if (strcmp(key, "k") == 0) {
        luaL_checktype(L, 3, LUA_TTABLE);
        if (f->k_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->k_tbl);
        lua_pushvalue(L, 3);
        f->k_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        return 0;
    }
    if (strcmp(key, "p") == 0) {
        luaL_checktype(L, 3, LUA_TTABLE);
        if (f->p_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->p_tbl);
        lua_pushvalue(L, 3);
        f->p_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        return 0;
    }
    if (strcmp(key, "lineinfo") == 0) {
        luaL_checktype(L, 3, LUA_TTABLE);
        if (f->lineinfo_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->lineinfo_tbl);
        lua_pushvalue(L, 3);
        f->lineinfo_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        return 0;
    }
    if (strcmp(key, "locvars") == 0) {
        luaL_checktype(L, 3, LUA_TTABLE);
        if (f->locvars_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->locvars_tbl);
        lua_pushvalue(L, 3);
        f->locvars_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        return 0;
    }
    if (strcmp(key, "upvalues") == 0) {
        luaL_checktype(L, 3, LUA_TTABLE);
        if (f->upvalues_tbl != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, f->upvalues_tbl);
        lua_pushvalue(L, 3);
        f->upvalues_tbl = luaL_ref(L, LUA_REGISTRYINDEX);
        return 0;
    }
    return 0;
}

static void push_proto(lua_State *L, luac_Proto *f) {
    luac_Proto *p = (luac_Proto *)lua_newuserdata(L, sizeof(luac_Proto));
    memcpy(p, f, sizeof(luac_Proto));
    /* reset table refs - the new userdata owns the C struct,
       but tables will be lazily created */
    p->code_tbl = LUA_NOREF;
    p->p_tbl = LUA_NOREF;
    p->k_tbl = LUA_NOREF;
    p->lineinfo_tbl = LUA_NOREF;
    p->locvars_tbl = LUA_NOREF;
    p->upvalues_tbl = LUA_NOREF;
    /* The original f's arrays are now owned by p (the userdata).
       Set f's pointers to NULL so caller doesn't double-free. */
    f->code = NULL;
    f->k_tag = NULL; f->k_str = NULL; f->k_num = NULL; f->k_bool = NULL;
    f->p = NULL;
    f->lineinfo = NULL;
    f->locvar_name = NULL; f->locvar_startpc = NULL; f->locvar_endpc = NULL;
    f->upval_name = NULL; f->upval_instack = NULL; f->upval_idx = NULL;
    f->source = NULL;
    luaL_getmetatable(L, "luac.Proto");
    lua_setmetatable(L, -2);
}

/*===========================================================================
** luac.undump / luac.dump
**=========================================================================*/

static int luac_undump(lua_State *L) {
    size_t len;
    const char *data = luaL_checklstring(L, 1, &len);
    int force_encrypted = lua_toboolean(L, 2);
    UndumpState S;
    S.buf = (const unsigned char *)data;
    S.pos = 0;
    S.len = len;
    S.encrypted = 0;

    if (CheckHeader(&S) != 0) {
        return luaL_error(L, "luac.undump: invalid bytecode header");
    }
    if (force_encrypted) S.encrypted = 1;

    /* main closure upvalue count (1 byte) */
    LoadByte(&S);

    luac_Proto *f = luac_alloc(sizeof(luac_Proto));
    LoadFunction(&S, f);

    push_proto(L, f);
    /* f is now owned by userdata; don't free */
    return 1;
}

static int luac_dump(lua_State *L) {
    luac_Proto *f = (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");

    /* sync all Lua tables back to C */
    sync_all_tables(L, f);

    DumpState D;
    D.buf = NULL;
    D.pos = 0;
    D.cap = 0;
    DumpGrow(&D, 1024);

    DumpHeader(&D);
    DumpByte(&D, (unsigned char)f->sizeupvalues);  /* main closure upvalue count */
    DumpFunction(&D, f);

    lua_pushlstring(L, (const char *)D.buf, D.pos);
    free(D.buf);
    return 1;
}

/*===========================================================================
** Instruction manipulation (defines equivalent)
**=========================================================================*/

/* Instruction field positions (Lua 5.3) */
#define SIZE_OP 6
#define SIZE_A  8
#define SIZE_B  9
#define SIZE_C  9
#define SIZE_Bx (SIZE_B + SIZE_C)
#define SIZE_Ax (SIZE_A + SIZE_B + SIZE_C)
#define POS_OP 0
#define POS_A  (POS_OP + SIZE_OP)
#define POS_C  (POS_A + SIZE_A)
#define POS_B  (POS_C + SIZE_C)
#define POS_Bx POS_C
#define POS_Ax POS_A
#define MAXARG_sBx ((1 << SIZE_Bx) / 2 - 1)

static unsigned int MASK1(int n, int p) {
    return ((~(unsigned int)0) >> (32 - n)) << p;
}
static unsigned int MASK0(int n, int p) { return ~MASK1(n, p); }

static int luac_GET_OPCODE(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, (i >> POS_OP) & MASK1(SIZE_OP, 0));
    return 1;
}
static int luac_SET_OPCODE(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int op = (unsigned int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, (lua_Integer)((i & MASK0(SIZE_OP, POS_OP)) | ((op << POS_OP) & MASK1(SIZE_OP, POS_OP))));
    return 1;
}
static int luac_GETARG_A(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, (i >> POS_A) & MASK1(SIZE_A, 0));
    return 1;
}
static int luac_SETARG_A(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int a = (unsigned int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, (lua_Integer)((i & MASK0(SIZE_A, POS_A)) | ((a << POS_A) & MASK1(SIZE_A, POS_A))));
    return 1;
}
static int luac_GETARG_B(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, (i >> POS_B) & MASK1(SIZE_B, 0));
    return 1;
}
static int luac_SETARG_B(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int b = (unsigned int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, (lua_Integer)((i & MASK0(SIZE_B, POS_B)) | ((b << POS_B) & MASK1(SIZE_B, POS_B))));
    return 1;
}
static int luac_GETARG_C(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, (i >> POS_C) & MASK1(SIZE_C, 0));
    return 1;
}
static int luac_SETARG_C(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int c = (unsigned int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, (lua_Integer)((i & MASK0(SIZE_C, POS_C)) | ((c << POS_C) & MASK1(SIZE_C, POS_C))));
    return 1;
}
static int luac_GETARG_Bx(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, (i >> POS_Bx) & MASK1(SIZE_Bx, 0));
    return 1;
}
static int luac_SETARG_Bx(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int bx = (unsigned int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, (lua_Integer)((i & MASK0(SIZE_Bx, POS_Bx)) | ((bx << POS_Bx) & MASK1(SIZE_Bx, POS_Bx))));
    return 1;
}
static int luac_GETARG_sBx(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    int bx = (int)((i >> POS_Bx) & MASK1(SIZE_Bx, 0));
    lua_pushinteger(L, bx - MAXARG_sBx);
    return 1;
}
static int luac_SETARG_sBx(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    int sbx = (int)luaL_checkinteger(L, 2);
    unsigned int bx = (unsigned int)(sbx + MAXARG_sBx);
    lua_pushinteger(L, (lua_Integer)((i & MASK0(SIZE_Bx, POS_Bx)) | ((bx << POS_Bx) & MASK1(SIZE_Bx, POS_Bx))));
    return 1;
}
static int luac_GETARG_Ax(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, (i >> POS_Ax) & MASK1(SIZE_Ax, 0));
    return 1;
}
static int luac_SETARG_Ax(lua_State *L) {
    unsigned int i = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int ax = (unsigned int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, (lua_Integer)((i & MASK0(SIZE_Ax, POS_Ax)) | ((ax << POS_Ax) & MASK1(SIZE_Ax, POS_Ax))));
    return 1;
}

/* CREATE_* functions */
static int luac_CREATE_ABC(lua_State *L) {
    unsigned int op = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int a = (unsigned int)luaL_checkinteger(L, 2);
    unsigned int b = (unsigned int)luaL_checkinteger(L, 3);
    unsigned int c = (unsigned int)luaL_checkinteger(L, 4);
    unsigned int ins = 0;
    ins |= (op << POS_OP) & MASK1(SIZE_OP, POS_OP);
    ins |= (a << POS_A) & MASK1(SIZE_A, POS_A);
    ins |= (b << POS_B) & MASK1(SIZE_B, POS_B);
    ins |= (c << POS_C) & MASK1(SIZE_C, POS_C);
    lua_pushinteger(L, (lua_Integer)ins);
    return 1;
}
static int luac_CREATE_ABx(lua_State *L) {
    unsigned int op = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int a = (unsigned int)luaL_checkinteger(L, 2);
    unsigned int bx = (unsigned int)luaL_checkinteger(L, 3);
    unsigned int ins = 0;
    ins |= (op << POS_OP) & MASK1(SIZE_OP, POS_OP);
    ins |= (a << POS_A) & MASK1(SIZE_A, POS_A);
    ins |= (bx << POS_Bx) & MASK1(SIZE_Bx, POS_Bx);
    lua_pushinteger(L, (lua_Integer)ins);
    return 1;
}
static int luac_CREATE_AsBx(lua_State *L) {
    unsigned int op = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int a = (unsigned int)luaL_checkinteger(L, 2);
    int sbx = (int)luaL_checkinteger(L, 3);
    unsigned int bx = (unsigned int)(sbx + MAXARG_sBx);
    unsigned int ins = 0;
    ins |= (op << POS_OP) & MASK1(SIZE_OP, POS_OP);
    ins |= (a << POS_A) & MASK1(SIZE_A, POS_A);
    ins |= (bx << POS_Bx) & MASK1(SIZE_Bx, POS_Bx);
    lua_pushinteger(L, (lua_Integer)ins);
    return 1;
}
static int luac_CREATE_Ax(lua_State *L) {
    unsigned int op = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int ax = (unsigned int)luaL_checkinteger(L, 2);
    unsigned int ins = 0;
    ins |= (op << POS_OP) & MASK1(SIZE_OP, POS_OP);
    ins |= (ax << POS_Ax) & MASK1(SIZE_Ax, POS_Ax);
    lua_pushinteger(L, (lua_Integer)ins);
    return 1;
}

/*===========================================================================
** Module registration
**=========================================================================*/

static const luaL_Reg luac_funcs[] = {
    {"undump", luac_undump},
    {"dump", luac_dump},
    {"GET_OPCODE", luac_GET_OPCODE},
    {"SET_OPCODE", luac_SET_OPCODE},
    {"GETARG_A", luac_GETARG_A},
    {"SETARG_A", luac_SETARG_A},
    {"GETARG_B", luac_GETARG_B},
    {"SETARG_B", luac_SETARG_B},
    {"GETARG_C", luac_GETARG_C},
    {"SETARG_C", luac_SETARG_C},
    {"GETARG_Bx", luac_GETARG_Bx},
    {"SETARG_Bx", luac_SETARG_Bx},
    {"GETARG_sBx", luac_GETARG_sBx},
    {"SETARG_sBx", luac_SETARG_sBx},
    {"GETARG_Ax", luac_GETARG_Ax},
    {"SETARG_Ax", luac_SETARG_Ax},
    {"CREATE_ABC", luac_CREATE_ABC},
    {"CREATE_ABx", luac_CREATE_ABx},
    {"CREATE_AsBx", luac_CREATE_AsBx},
    {"CREATE_Ax", luac_CREATE_Ax},
    {NULL, NULL}
};

/* Opcode names for Lua 5.3 (47 opcodes 0-46, plus andlua extensions) */
static const char *const opnames[] = {
    "MOVE", "LOADK", "LOADKX", "LOADBOOL", "LOADNIL",
    "GETUPVAL", "GETTABUP", "GETTABLE", "SETTABUP", "SETUPVAL",
    "SETTABLE", "NEWTABLE", "SELF", "ADD", "SUB", "MUL", "MOD",
    "POW", "DIV", "IDIV", "BAND", "BOR", "BXOR", "SHL", "SHR",
    "UNM", "BNOT", "NOT", "LEN", "CONCAT",
    "JMP", "EQ", "LT", "LE",
    "TEST", "TESTSET", "CALL", "TAILCALL", "RETURN",
    "FORLOOP", "FORPREP", "TFORCALL", "TFORLOOP",
    "SETLIST", "CLOSURE", "VARARG",
    "EXTRAARG",  /* 47 */
    NULL
};

int luaopen_luac(lua_State *L) {
    /* Proto metatable */
    luaL_newmetatable(L, "luac.Proto");
    lua_pushcfunction(L, proto_index);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, proto_newindex);
    lua_setfield(L, -2, "__newindex");
    lua_pushcfunction(L, proto_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);

    /* module table */
    luaL_newlib(L, luac_funcs);

    /* opcode constants */
    for (int i = 0; opnames[i]; i++) {
        char buf[32];
        snprintf(buf, sizeof(buf), "OP_%s", opnames[i]);
        lua_pushinteger(L, i);
        lua_setfield(L, -2, buf);
    }
    /* andlua extension opcodes */
    lua_pushinteger(L, 48); lua_setfield(L, -2, "OP_FULLOPSIZE");

    /* opcode names table */
    lua_newtable(L);
    for (int i = 0; opnames[i]; i++) {
        lua_pushstring(L, opnames[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "OPCODE_NAMES");

    return 1;
}
