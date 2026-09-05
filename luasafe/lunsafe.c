/*
** LUnSafe library - low-level memory and bytecode manipulation
** Reconstructed from andlua libluajava.so
*/

#define lunsafe_c
#define LUA_LIB

#include "lprefix.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/mman.h>
#include <dlfcn.h>
#endif

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "lobject.h"
#include "lstate.h"
#include "lcode.h"
#include "lopcodes.h"
#include "lundump.h"
#include "lgc.h"
#include "lmem.h"


/* opcode remap table: original opcode -> stored opcode
** index 40 is skipped (maps 40->41, 41->42, ... 53->54)
*/
static const unsigned int opcode_remap[54] = {
    0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,
    20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,
    41,42,43,44,45,46,47,48,49,50,51,52,53,54
};

/* reverse map: stored opcode -> original opcode, initialized at runtime */
static unsigned int opcode_revmap[256];


/* helper: convert stack index to TValue* (like lapi.c index2addr) */
static TValue *idx2addr(lua_State *L, int idx) {
    if (idx > 0) {
        TValue *o = L->ci->func + idx;
        return (o <= L->top - 1) ? o : NULL;
    }
    if (idx < 0)
        return L->top + idx;
    return NULL;
}


/* ===================== main table functions ===================== */

static int l_malloc(lua_State *L) {
    size_t size = (size_t)luaL_checkinteger(L, 1);
    void *p = malloc(size);
    lua_pushlightuserdata(L, p);
    return 1;
}

static int l_free(lua_State *L) {
    void *p = lua_touserdata(L, 1);
    free(p);
    return 0;
}

static int l_realloc(lua_State *L) {
    void *p = lua_touserdata(L, 1);
    size_t size = (size_t)luaL_checkinteger(L, 2);
    void *r = realloc(p, size);
    lua_pushlightuserdata(L, r);
    return 1;
}

static int l_memcpy(lua_State *L) {
    void *dst = lua_touserdata(L, 1);
    const void *src = lua_touserdata(L, 2);
    size_t n = (size_t)luaL_checkinteger(L, 3);
    memcpy(dst, src, n);
    return 0;
}

static int l_memset(lua_State *L) {
    void *p = lua_touserdata(L, 1);
    int c = (int)luaL_checkinteger(L, 2);
    size_t n = (size_t)luaL_checkinteger(L, 3);
    memset(p, c, n);
    return 0;
}

static int l_memmove(lua_State *L) {
    void *dst = lua_touserdata(L, 1);
    const void *src = lua_touserdata(L, 2);
    size_t n = (size_t)luaL_checkinteger(L, 3);
    memmove(dst, src, n);
    return 0;
}

static int l_memcmp(lua_State *L) {
    const void *a = lua_touserdata(L, 1);
    const void *b = lua_touserdata(L, 2);
    size_t n = (size_t)luaL_checkinteger(L, 3);
    int r = memcmp(a, b, n);
    lua_pushinteger(L, r);
    return 1;
}

static int l_mmap(lua_State *L) {
    void *addr = lua_touserdata(L, 1);
    size_t length = (size_t)luaL_checkinteger(L, 2);
    int prot = (int)luaL_checkinteger(L, 3);
    int flags = (int)luaL_checkinteger(L, 4);
    int fd = (int)luaL_checkinteger(L, 5);
    off_t offset = (off_t)luaL_checkinteger(L, 6);
#ifdef _WIN32
    (void)addr; (void)prot; (void)flags; (void)fd; (void)offset;
    void *r = VirtualAlloc(NULL, length, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
#else
    void *r = mmap(addr, length, prot, flags, fd, offset);
#endif
    lua_pushlightuserdata(L, r);
    return 1;
}

static int l_munmap(lua_State *L) {
    void *addr = lua_touserdata(L, 1);
    size_t length = (size_t)luaL_checkinteger(L, 2);
#ifdef _WIN32
    (void)length;
    int r = VirtualFree(addr, 0, MEM_RELEASE) ? 0 : -1;
#else
    int r = munmap(addr, length);
#endif
    lua_pushinteger(L, r);
    return 1;
}

static int l_mprotect(lua_State *L) {
    void *addr = lua_touserdata(L, 1);
    size_t length = (size_t)luaL_checkinteger(L, 2);
    int prot = (int)luaL_checkinteger(L, 3);
#ifdef _WIN32
    DWORD old;
    int r = VirtualProtect(addr, length, PAGE_READWRITE, &old) ? 0 : -1;
#else
    int r = mprotect(addr, length, prot);
#endif
    lua_pushinteger(L, r);
    return 1;
}

static int l_mincore(lua_State *L) {
    void *addr = lua_touserdata(L, 1);
    size_t length = (size_t)luaL_checkinteger(L, 2);
    unsigned char *vec = (unsigned char *)lua_touserdata(L, 3);
#ifdef _WIN32
    (void)addr; (void)length; (void)vec;
    int r = -1;
#else
    int r = mincore(addr, length, vec);
#endif
    lua_pushinteger(L, r);
    return 1;
}

static int l_dlopen(lua_State *L) {
    const char *filename = luaL_checklstring(L, 1, NULL);
    int flags = (int)luaL_checkinteger(L, 2);
#ifdef _WIN32
    (void)flags;
    void *h = (void *)LoadLibraryA(filename);
#else
    void *h = dlopen(filename, flags);
#endif
    lua_pushlightuserdata(L, h);
    return 1;
}

static int l_dlclose(lua_State *L) {
    void *h = lua_touserdata(L, 1);
#ifdef _WIN32
    int r = FreeLibrary((HMODULE)h) ? 0 : -1;
#else
    int r = dlclose(h);
#endif
    lua_pushinteger(L, r);
    return 1;
}

static int l_dlsym(lua_State *L) {
    void *h = lua_touserdata(L, 1);
    const char *symbol = luaL_checklstring(L, 2, NULL);
#ifdef _WIN32
    void *p = (void *)GetProcAddress((HMODULE)h, symbol);
#else
    void *p = dlsym(h, symbol);
#endif
    lua_pushlightuserdata(L, p);
    return 1;
}

static int l_fopen(lua_State *L) {
    const char *path = luaL_checklstring(L, 1, NULL);
    const char *mode = luaL_checklstring(L, 2, NULL);
    FILE *f = fopen(path, mode);
    lua_pushlightuserdata(L, f);
    return 1;
}

static int l_fclose(lua_State *L) {
    FILE *f = (FILE *)lua_touserdata(L, 1);
    int r = fclose(f);
    lua_pushinteger(L, r);
    return 1;
}

static int l_fread(lua_State *L) {
    void *ptr = lua_touserdata(L, 1);
    size_t size = (size_t)luaL_checkinteger(L, 2);
    size_t nmemb = (size_t)luaL_checkinteger(L, 3);
    FILE *f = (FILE *)lua_touserdata(L, 4);
    size_t r = fread(ptr, size, nmemb, f);
    lua_pushinteger(L, (lua_Integer)r);
    return 1;
}

static int l_fwrite(lua_State *L) {
    const void *ptr = lua_touserdata(L, 1);
    size_t size = (size_t)luaL_checkinteger(L, 2);
    size_t nmemb = (size_t)luaL_checkinteger(L, 3);
    FILE *f = (FILE *)lua_touserdata(L, 4);
    size_t r = fwrite(ptr, size, nmemb, f);
    lua_pushinteger(L, (lua_Integer)r);
    return 1;
}

static int l_fseek(lua_State *L) {
    FILE *f = (FILE *)lua_touserdata(L, 1);
    long offset = (long)luaL_checkinteger(L, 2);
    int whence = (int)luaL_checkinteger(L, 3);
    int r = fseek(f, offset, whence);
    lua_pushinteger(L, r);
    return 1;
}

static int l_ftell(lua_State *L) {
    FILE *f = (FILE *)lua_touserdata(L, 1);
    long r = ftell(f);
    lua_pushinteger(L, (lua_Integer)r);
    return 1;
}

static int l_ptrpos(lua_State *L) {
    void *ptr = lua_touserdata(L, 1);
    ptrdiff_t offset = (ptrdiff_t)luaL_checkinteger(L, 2);
    lua_pushlightuserdata(L, (char *)ptr + offset);
    return 1;
}

static int l_readmem(lua_State *L) {
    void *ptr = lua_touserdata(L, 1);
    size_t len = (size_t)luaL_checkinteger(L, 2);
    lua_pushlstring(L, (const char *)ptr, len);
    return 1;
}

static int l_writemem(lua_State *L) {
    void *ptr = lua_touserdata(L, 1);
    size_t len = (size_t)luaL_checkinteger(L, 2);
    size_t slen;
    const char *data = luaL_checklstring(L, 3, &slen);
    memcpy(ptr, data, len);
    return 0;
}

/* Convert a Lua value at index 1 to its raw memory pointer and size.
** Returns 2 values: (pointer, size) or (nil) if unsupported type.
*/
static int l_luatype2memptr(lua_State *L) {
    if (lua_gettop(L) != 1) {
        lua_pushnil(L);
        return 1;
    }
    TValue *o = idx2addr(L, 1);
    if (o == NULL) { lua_pushnil(L); return 1; }
    int tt = o->tt_ & 0x3F;
    const void *ptr = NULL;
    size_t size = 0;

    switch (tt) {
        case LUA_TNIL:
            lua_pushnil(L);
            return 1;
        case LUA_TBOOLEAN:
            ptr = &o->value_.b;
            size = 1;
            break;
        case LUA_TLIGHTUSERDATA:
            ptr = o->value_.p;
            size = 0;
            break;
        case LUA_TNUMFLT:
            ptr = &o->value_.n;
            size = sizeof(lua_Number);
            break;
        case LUA_TNUMINT:
            ptr = &o->value_.i;
            size = sizeof(lua_Integer);
            break;
        case LUA_TSHRSTR:
        case LUA_TLNGSTR: {
            TString *ts = gco2ts(o->value_.gc);
            ptr = getstr(ts);
            size = (ts->tt == LUA_TSHRSTR) ? ts->shrlen : ts->u.lnglen;
            break;
        }
        case LUA_TTABLE: {
            Table *t = gco2t(o->value_.gc);
            ptr = t->array;
            size = (t->node == t->lastfree) ? 0 :
                   (size_t)((char *)t->lastfree - (char *)t->node);
            break;
        }
        case LUA_TUSERDATA: {
            Udata *u = gco2u(o->value_.gc);
            ptr = (char *)(u) + sizeof(UUdata);
            size = u->len;
            break;
        }
        case LUA_TTHREAD:
            ptr = gco2th(o->value_.gc);
            size = 0;
            break;
        default:
            lua_pushnil(L);
            return 1;
    }
    lua_pushlightuserdata(L, (void *)ptr);
    lua_pushinteger(L, (lua_Integer)size);
    return 2;
}

/* Call a raw C function pointer with the Lua state. */
static int l_dynamic(lua_State *L) {
    typedef int (*rawfunc)(lua_State *);
    rawfunc f = (rawfunc)lua_touserdata(L, 1);
    lua_rotate(L, 1, -1);
    lua_settop(L, -2);
    return f(L);
}

static int l_makePtr(lua_State *L) {
    lua_Integer val = luaL_checkinteger(L, 1);
    lua_pushlightuserdata(L, (void *)(uintptr_t)val);
    return 1;
}

static int l_getLuaState(lua_State *L) {
    lua_pushlightuserdata(L, L);
    return 1;
}


/* ===================== TypeRead functions ===================== */

#define DEF_TYPEREAD(name, ctype, pushfunc) \
static int tr_##name(lua_State *L) { \
    ctype *p = (ctype *)lua_touserdata(L, 1); \
    pushfunc(L, *p); \
    return 1; \
}

DEF_TYPEREAD(Char, unsigned char, lua_pushinteger)
DEF_TYPEREAD(UnsignedChar, unsigned char, lua_pushinteger)
DEF_TYPEREAD(Short, short, lua_pushinteger)
DEF_TYPEREAD(UnsignedShort, unsigned short, lua_pushinteger)
DEF_TYPEREAD(Int, int, lua_pushinteger)
DEF_TYPEREAD(UnsignedInt, unsigned int, lua_pushinteger)
DEF_TYPEREAD(Long, long, lua_pushinteger)
DEF_TYPEREAD(UnsignedLong, unsigned long, lua_pushinteger)
DEF_TYPEREAD(SizeT, size_t, lua_pushinteger)
DEF_TYPEREAD(Float, float, lua_pushnumber)
DEF_TYPEREAD(Double, double, lua_pushnumber)

static int tr_Pointer(lua_State *L) {
    void **p = (void **)lua_touserdata(L, 1);
    lua_pushlightuserdata(L, *p);
    return 1;
}


/* ===================== TypeWrite functions ===================== */

#define DEF_TYPEWRITE(name, ctype, checkfunc) \
static int tw_##name(lua_State *L) { \
    ctype *p = (ctype *)lua_touserdata(L, 1); \
    *p = (ctype)checkfunc(L, 2); \
    return 0; \
}

DEF_TYPEWRITE(Char, unsigned char, luaL_checkinteger)
DEF_TYPEWRITE(UnsignedChar, unsigned char, luaL_checkinteger)
DEF_TYPEWRITE(Short, short, luaL_checkinteger)
DEF_TYPEWRITE(UnsignedShort, unsigned short, luaL_checkinteger)
DEF_TYPEWRITE(Int, int, luaL_checkinteger)
DEF_TYPEWRITE(UnsignedInt, unsigned int, luaL_checkinteger)
DEF_TYPEWRITE(Long, long, luaL_checkinteger)
DEF_TYPEWRITE(UnsignedLong, unsigned long, luaL_checkinteger)
DEF_TYPEWRITE(SizeT, size_t, luaL_checkinteger)
DEF_TYPEWRITE(Float, float, luaL_checknumber)
DEF_TYPEWRITE(Double, double, luaL_checknumber)

static int tw_Pointer(lua_State *L) {
    void **p = (void **)lua_touserdata(L, 1);
    *p = lua_touserdata(L, 2);
    return 0;
}


/* ===================== opcode / LASM functions ===================== */

static void push_proto_info(lua_State *L, Proto *f, int detailed) {
    lua_createtable(L, 0, 0);
    lua_pushlightuserdata(L, f);
    lua_setfield(L, -2, "Proto");
    lua_pushlightuserdata(L, f->next);
    lua_setfield(L, -2, "next");
    lua_pushinteger(L, f->tt);
    lua_setfield(L, -2, "tt");
    lua_pushinteger(L, f->marked);
    lua_setfield(L, -2, "marked");
    lua_pushinteger(L, f->numparams);
    lua_setfield(L, -2, "numparams");
    lua_pushinteger(L, f->is_vararg);
    lua_setfield(L, -2, "is_vararg");
    lua_pushinteger(L, f->maxstacksize);
    lua_setfield(L, -2, "maxstacksize");
    lua_pushinteger(L, f->sizeupvalues);
    lua_setfield(L, -2, "sizeupvalues");
    lua_pushinteger(L, f->sizek);
    lua_setfield(L, -2, "sizek");
    lua_pushinteger(L, f->sizecode);
    lua_setfield(L, -2, "sizecode");
    lua_pushinteger(L, f->sizelineinfo);
    lua_setfield(L, -2, "sizelineinfo");
    lua_pushinteger(L, f->sizep);
    lua_setfield(L, -2, "sizep");
    lua_pushinteger(L, f->sizelocvars);
    lua_setfield(L, -2, "sizelocvars");
    lua_pushinteger(L, f->linedefined);
    lua_setfield(L, -2, "linedefined");
    lua_pushinteger(L, f->lastlinedefined);
    lua_setfield(L, -2, "lastlinedefined");

    if (detailed) {
        int i;
        lua_createtable(L, 0, 0);
        for (i = 0; i < f->sizek; i++) {
            TValue *o = &f->k[i];
            int t = o->tt_ & 0x3F;
            switch (t) {
                case LUA_TNIL: lua_pushnil(L); break;
                case LUA_TBOOLEAN: lua_pushboolean(L, o->value_.b); break;
                case LUA_TNUMFLT: lua_pushnumber(L, o->value_.n); break;
                case LUA_TNUMINT: lua_pushinteger(L, o->value_.i); break;
                case LUA_TSHRSTR:
                case LUA_TLNGSTR: {
                    TString *ts = gco2ts(o->value_.gc);
                    lua_pushlstring(L, getstr(ts), ts->shrlen);
                    break;
                }
                default: lua_pushnil(L); break;
            }
            lua_rawseti(L, -2, i);
        }
        lua_setfield(L, -2, "k");

        lua_createtable(L, 0, 0);
        for (i = 0; i < f->sizecode; i++) {
            Instruction ins = f->code[i];
            lua_createtable(L, 0, 0);
            lua_pushinteger(L, ins);
            lua_setfield(L, -2, "ins");
            lua_pushstring(L, "");
            lua_setfield(L, -2, "opname");
            {
                unsigned int op = ins & 0x3F;
                if (op <= 0x35) {
                    lua_pushinteger(L, (ins >> 6) & 0xFF);
                    lua_setfield(L, -2, "a");
                    unsigned int mode = (op < NUM_OPCODES) ? (luaP_opmodes[op] & 3) : 0;
                    switch (mode) {
                        case 0:
                            lua_pushinteger(L, ins >> 23);
                            lua_setfield(L, -2, "b");
                            lua_pushinteger(L, (ins >> 14) & 0x1FF);
                            lua_setfield(L, -2, "c");
                            break;
                        case 1:
                            lua_pushinteger(L, ins >> 14);
                            lua_setfield(L, -2, "bx");
                            break;
                        case 2:
                            lua_pushinteger(L, (int)(ins >> 14) - MAXARG_sBx);
                            lua_setfield(L, -2, "sbx");
                            break;
                        case 3:
                            lua_pushinteger(L, ins >> 6);
                            lua_setfield(L, -2, "ax");
                            break;
                    }
                }
            }
            lua_rawseti(L, -2, i);
        }
        lua_setfield(L, -2, "code");

        lua_createtable(L, 0, 0);
        for (i = 0; i < f->sizep; i++) {
            push_proto_info(L, f->p[i], detailed);
            lua_rawseti(L, -2, i);
        }
        lua_setfield(L, -2, "p");

        lua_createtable(L, 0, 0);
        for (i = 0; i < f->sizelineinfo; i++) {
            lua_pushinteger(L, f->lineinfo[i]);
            lua_rawseti(L, -2, i);
        }
        lua_setfield(L, -2, "lineinfo");

        lua_createtable(L, 0, 0);
        for (i = 0; i < f->sizelocvars; i++) {
            lua_createtable(L, 0, 0);
            lua_pushinteger(L, f->locvars[i].startpc);
            lua_setfield(L, -2, "startpc");
            lua_pushinteger(L, f->locvars[i].endpc);
            lua_setfield(L, -2, "endpc");
            if (f->locvars[i].varname) {
                lua_pushstring(L, getstr(f->locvars[i].varname));
                lua_setfield(L, -2, "varname");
            }
            lua_rawseti(L, -2, i);
        }
        lua_setfield(L, -2, "locvars");

        lua_createtable(L, 0, 0);
        for (i = 0; i < f->sizeupvalues; i++) {
            lua_createtable(L, 0, 0);
            lua_pushinteger(L, f->upvalues[i].instack);
            lua_setfield(L, -2, "instack");
            lua_pushinteger(L, f->upvalues[i].idx);
            lua_setfield(L, -2, "idx");
            if (f->upvalues[i].name) {
                lua_pushstring(L, getstr(f->upvalues[i].name));
                lua_setfield(L, -2, "name");
            }
            lua_rawseti(L, -2, i);
        }
    } else {
        lua_pushlightuserdata(L, f->k);
        lua_setfield(L, -2, "k");
        lua_pushlightuserdata(L, f->code);
        lua_setfield(L, -2, "code");
        lua_pushlightuserdata(L, f->p);
        lua_setfield(L, -2, "p");
        lua_pushlightuserdata(L, f->lineinfo);
        lua_setfield(L, -2, "lineinfo");
        lua_pushlightuserdata(L, f->locvars);
        lua_setfield(L, -2, "locvars");
        lua_pushlightuserdata(L, f->upvalues);
    }
    lua_setfield(L, -2, "upvalues");
    lua_pushlightuserdata(L, f->cache);
    lua_setfield(L, -2, "cache");
    if (f->source) {
        lua_pushstring(L, getstr(f->source));
        lua_setfield(L, -2, "source");
    }
    lua_pushlightuserdata(L, f->gclist);
    lua_setfield(L, -2, "gclist");
}

static int lasm_ProtoInfo(lua_State *L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    int detailed = lua_toboolean(L, 2);
    TValue *o = idx2addr(L, 1);
    if (o == NULL || (o->tt_ & 0x3F) != LUA_TLCL) return 0;
    Proto *f = gco2lcl(o->value_.gc)->p;
    push_proto_info(L, f, detailed);
    return 1;
}

static int lasm_pindex(lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    Proto *f = (Proto *)lua_touserdata(L, 1);
    int idx = (int)luaL_checkinteger(L, 2);
    int sizecode = f->sizecode;
    if (idx < 0) {
        idx += sizecode;
        if (idx < 0) return 0;
    }
    if (idx >= sizecode) return 0;
    if (f->code == NULL) return 0;
    lua_pushlightuserdata(L, &f->code[idx]);
    return 1;
}

static int lasm_kindex(lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    Proto *f = (Proto *)lua_touserdata(L, 1);
    int idx = (int)luaL_checkinteger(L, 2);
    int sizek = f->sizek;
    if (idx < 0) {
        idx += sizek;
        if (idx < 0) return 0;
    }
    if (idx >= sizek) return 0;
    if (f->k == NULL) return 0;
    memcpy(L->top, &f->k[idx], sizeof(TValue));
    L->top++;
    return 1;
}

static int lasm_handleInst(lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    Proto *f = (Proto *)lua_touserdata(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    if (f->sizecode >= 1) {
        int i;
        for (i = 0; i < f->sizecode; i++) {
            Instruction ins = f->code[i];
            lua_pushvalue(L, 2);
            lua_pushinteger(L, ins);
            lua_callk(L, 1, 1, 0, NULL);
            if (lua_type(L, -1) != LUA_TNIL) {
                Instruction newins = (Instruction)luaL_checkinteger(L, -1);
                lua_settop(L, -2);
                f->code[i] = newins;
            } else {
                lua_settop(L, -2);
            }
        }
    }
    return 0;
}

static int lasm_replaceInst(lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    Proto *f = (Proto *)lua_touserdata(L, 1);
    luaL_checktype(L, 2, LUA_TUSERDATA);
    Instruction *newcode = (Instruction *)lua_touserdata(L, 2);
    int count = (int)luaL_checkinteger(L, 3);
    if (f->code != NULL) free(f->code);
    Instruction *code = (Instruction *)malloc(count * sizeof(Instruction));
    f->code = code;
    memcpy(code, newcode, count * sizeof(Instruction));
    f->sizecode = count;
    return 0;
}

static int lasm_replaceK(lua_State *L) {
    luaL_checktype(L, 1, LUA_TUSERDATA);
    Proto *f = (Proto *)lua_touserdata(L, 1);
    int idx = (int)luaL_checkinteger(L, 2);
    if (lua_gettop(L) == 2)
        lua_pushnil(L);
    else
        lua_pushvalue(L, 3);
    int sizek = f->sizek;
    if ((idx & 0x80000000) == 0 || (idx += sizek, idx >= 0)) {
        if (idx < sizek) {
            TValue *src = L->top - 1;
            TValue *dst = &f->k[idx];
            memcpy(dst, src, sizeof(TValue));
        }
    }
    return 0;
}

static int lasm_GET_OPCODE(lua_State *L) {
    unsigned int ins = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int op = ins & 0x3F;
    if (op <= 0x35) {
        lua_pushinteger(L, opcode_revmap[op]);
        lua_pushboolean(L, 1);
    } else {
        lua_pushinteger(L, 0);
        lua_pushboolean(L, 0);
    }
    return 2;
}

#define DEF_GETARG(name, expr) \
static int lasm_##name(lua_State *L) { \
    unsigned int ins = (unsigned int)luaL_checkinteger(L, 1); \
    lua_pushinteger(L, (lua_Integer)(expr)); \
    return 1; \
}

DEF_GETARG(GETARG_A, (ins >> 6) & 0xFF)
DEF_GETARG(GETARG_B, ins >> 23)
DEF_GETARG(GETARG_C, (ins >> 14) & 0x1FF)
DEF_GETARG(GETARG_Bx, ins >> 14)
DEF_GETARG(GETARG_sBx, (int)(ins >> 14) - MAXARG_sBx)
DEF_GETARG(GETARG_Ax, ins >> 6)

static int lasm_SET_OPCODE(lua_State *L) {
    unsigned int ins = (unsigned int)luaL_checkinteger(L, 1);
    unsigned int op = (unsigned int)luaL_checkinteger(L, 2);
    int raw = lua_toboolean(L, 3);
    if (!raw && op <= 0x35)
        op = opcode_remap[op];
    lua_pushinteger(L, (lua_Integer)((ins & ~0x3Fu) | (op & 0x3F)));
    return 1;
}

#define DEF_SETARG(name, expr) \
static int lasm_##name(lua_State *L) { \
    unsigned int ins = (unsigned int)luaL_checkinteger(L, 1); \
    unsigned int val = (unsigned int)luaL_checkinteger(L, 2); \
    lua_pushinteger(L, (lua_Integer)(expr)); \
    return 1; \
}

DEF_SETARG(SETARG_A, ((val << 6) & 0x3FC0) | (ins & 0xFFFFC03F))
DEF_SETARG(SETARG_B, (val << 23) | (ins & 0x7FFFFF))
DEF_SETARG(SETARG_C, ((val << 14) & 0x7FC000) | (ins & 0xFF803FFF))
DEF_SETARG(SETARG_Bx, (val << 14) | (ins & 0x3FFF))
DEF_SETARG(SETARG_sBx, (((val << 14) + (MAXARG_sBx << 14)) & 0xFFFFC000) | (ins & 0x3FFF))
DEF_SETARG(SETARG_Ax, (val << 6) | (ins & 0x3F))

static int lasm_ISK(lua_State *L) {
    int r = (int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, r & 0x100);
    return 1;
}

static int lasm_INDEXK(lua_State *L) {
    int r = (int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, r & ~0x100);
    return 1;
}

static int lasm_RKASK(lua_State *L) {
    int r = (int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, r | 0x100);
    return 1;
}


/* ===================== library registration ===================== */

static const luaL_Reg mainlib[] = {
    {"malloc", l_malloc},
    {"free", l_free},
    {"realloc", l_realloc},
    {"memcpy", l_memcpy},
    {"memset", l_memset},
    {"memmove", l_memmove},
    {"memcmp", l_memcmp},
    {"mmap", l_mmap},
    {"munmap", l_munmap},
    {"mprotect", l_mprotect},
    {"mincore", l_mincore},
    {"dlopen", l_dlopen},
    {"dlclose", l_dlclose},
    {"dlsym", l_dlsym},
    {"fopen", l_fopen},
    {"fclose", l_fclose},
    {"fread", l_fread},
    {"fwrite", l_fwrite},
    {"fseek", l_fseek},
    {"ftell", l_ftell},
    {"ptrpos", l_ptrpos},
    {"readmem", l_readmem},
    {"writemem", l_writemem},
    {"luatype2memptr", l_luatype2memptr},
    {"dynamic", l_dynamic},
    {"makePtr", l_makePtr},
    {"getLuaState", l_getLuaState},
    {NULL, NULL}
};

static const luaL_Reg typereadlib[] = {
    {"Char", tr_Char},
    {"UnsignedChar", tr_UnsignedChar},
    {"Short", tr_Short},
    {"UnsignedShort", tr_UnsignedShort},
    {"Int", tr_Int},
    {"UnsignedInt", tr_UnsignedInt},
    {"Long", tr_Long},
    {"UnsignedLong", tr_UnsignedLong},
    {"Float", tr_Float},
    {"Double", tr_Double},
    {"Pointer", tr_Pointer},
    {"SizeT", tr_SizeT},
    {NULL, NULL}
};

static const luaL_Reg typewritelib[] = {
    {"Char", tw_Char},
    {"UnsignedChar", tw_UnsignedChar},
    {"Short", tw_Short},
    {"UnsignedShort", tw_UnsignedShort},
    {"Int", tw_Int},
    {"UnsignedInt", tw_UnsignedInt},
    {"Long", tw_Long},
    {"UnsignedLong", tw_UnsignedLong},
    {"Float", tw_Float},
    {"Double", tw_Double},
    {"Pointer", tw_Pointer},
    {"SizeT", tw_SizeT},
    {NULL, NULL}
};

static const luaL_Reg lasmlib[] = {
    {"ProtoInfo", lasm_ProtoInfo},
    {"pindex", lasm_pindex},
    {"kindex", lasm_kindex},
    {"handleInst", lasm_handleInst},
    {"replaceInst", lasm_replaceInst},
    {"replaceK", lasm_replaceK},
    {"GET_OPCODE", lasm_GET_OPCODE},
    {"GETARG_A", lasm_GETARG_A},
    {"GETARG_B", lasm_GETARG_B},
    {"GETARG_C", lasm_GETARG_C},
    {"GETARG_Bx", lasm_GETARG_Bx},
    {"GETARG_sBx", lasm_GETARG_sBx},
    {"GETARG_Ax", lasm_GETARG_Ax},
    {"SET_OPCODE", lasm_SET_OPCODE},
    {"SETARG_A", lasm_SETARG_A},
    {"SETARG_B", lasm_SETARG_B},
    {"SETARG_C", lasm_SETARG_C},
    {"SETARG_Bx", lasm_SETARG_Bx},
    {"SETARG_sBx", lasm_SETARG_sBx},
    {"SETARG_Ax", lasm_SETARG_Ax},
    {"ISK", lasm_ISK},
    {"INDEXK", lasm_INDEXK},
    {"RKASK", lasm_RKASK},
    {NULL, NULL}
};

static const char *const opnames[] = {
    "OP_MOVE","OP_LOADK","OP_LOADKX","OP_LOADBOOL","OP_LOADNIL",
    "OP_GETUPVAL","OP_GETTABUP","OP_GETTABLE","OP_SETTABUP","OP_SETUPVAL",
    "OP_SETTABLE","OP_NEWTABLE","OP_SELF","OP_ADD","OP_SUB",
    "OP_MUL","OP_MOD","OP_POW","OP_DIV","OP_IDIV",
    "OP_BAND","OP_BOR","OP_BXOR","OP_SHL","OP_SHR",
    "OP_UNM","OP_BNOT","OP_NOT","OP_LEN","OP_CONCAT",
    "OP_JMP","OP_EQ","OP_LT","OP_LE","OP_TEST",
    "OP_TESTSET","OP_CALL","OP_TAILCALL","OP_RETURN","OP_FORLOOP",
    "OP_FORPREP","OP_TFORCALL","OP_TFORLOOP","OP_SETLIST","OP_CLOSURE",
    "OP_VARARG","OP_EXTRAARG","OP_TBC","OP_NEWARRAY","OP_TFOREACH",
    "OP_SECTION","OP_IS","OP_TRY","OP_TRYRETURN"
};

LUAMOD_API int luaopen_LUnSafe(lua_State *L) {
    unsigned int i;

    for (i = 0; i < 256; i++)
        opcode_revmap[i] = 0xFFFFFFFF;
    for (i = 0; i < 54; i++)
        opcode_revmap[opcode_remap[i]] = i;

    luaL_checkversion_(L, LUA_VERSION_NUM, LUAL_NUMSIZES);

    lua_createtable(L, 0, 27);
    luaL_setfuncs(L, mainlib, 0);

    luaL_checkversion_(L, LUA_VERSION_NUM, LUAL_NUMSIZES);
    lua_createtable(L, 0, 12);
    luaL_setfuncs(L, typereadlib, 0);
    lua_setfield(L, -2, "TypeRead");

    luaL_checkversion_(L, LUA_VERSION_NUM, LUAL_NUMSIZES);
    lua_createtable(L, 0, 12);
    luaL_setfuncs(L, typewritelib, 0);
    lua_setfield(L, -2, "TypeWrite");

    luaL_checkversion_(L, LUA_VERSION_NUM, LUAL_NUMSIZES);
    lua_createtable(L, 0, 23);
    luaL_setfuncs(L, lasmlib, 0);
    for (i = 0; i < 54; i++) {
        lua_pushinteger(L, i);
        lua_setfield(L, -2, opnames[i]);
    }
    lua_setfield(L, -2, "LASM");

    return 1;
}
