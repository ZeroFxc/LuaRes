/*
** integrity_check.c - 运行时完整性校验模块
** 只用标准库（debug.getinfo, string.dump），不依赖和lua特有函数
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "luac.h"

/* FNV-1a 32位哈希 */
static unsigned int fnv1a_byte(unsigned int h, unsigned char b) {
    h ^= b;
    h *= 16777619u;
    return h;
}

/* 递归计算 Proto 的哈希 */
static unsigned int hash_proto(const luac_Proto *p) {
    unsigned int h = 2166136261u;
    for (int i = 0; i < p->sizecode; i++) {
        unsigned int ins = p->code[i];
        h = fnv1a_byte(h, ins & 0xFF);
        h = fnv1a_byte(h, (ins >> 8) & 0xFF);
        h = fnv1a_byte(h, (ins >> 16) & 0xFF);
        h = fnv1a_byte(h, (ins >> 24) & 0xFF);
    }
    for (int i = 0; i < p->sizek; i++) {
        int t = p->k_tag[i];
        h = fnv1a_byte(h, (unsigned char)t);
        if (t == LUA_TNUMBER) {
            unsigned char *buf = (unsigned char *)&p->k_num[i];
            for (size_t j = 0; j < sizeof(double); j++) h = fnv1a_byte(h, buf[j]);
        } else if (t == LUA_TSTRING && p->k_str[i]) {
            int slen = p->k_str_len ? (p->k_str_len[i] < 0 ? -p->k_str_len[i] : p->k_str_len[i]) : (int)strlen(p->k_str[i]);
            for (int j = 0; j < slen; j++) h = fnv1a_byte(h, (unsigned char)p->k_str[i][j]);
        } else if (t == LUA_TBOOLEAN) {
            h = fnv1a_byte(h, p->k_bool[i] ? 1 : 0);
        }
    }
    for (int i = 0; i < p->sizep; i++) {
        if (p->p[i]) {
            unsigned int sh = hash_proto(p->p[i]);
            h = fnv1a_byte(h, sh & 0xFF);
            h = fnv1a_byte(h, (sh >> 8) & 0xFF);
            h = fnv1a_byte(h, (sh >> 16) & 0xFF);
            h = fnv1a_byte(h, (sh >> 24) & 0xFF);
        }
    }
    return h;
}

/* 用传入的 L 编译校验函数，深拷贝返回 Proto */
static luac_Proto *compile_checker(lua_State *L, unsigned int hash_val) {
    char src[2048];
    snprintf(src, sizeof(src),
        "local __f=debug.getinfo(2,'f').func\n"
        "local __bc=string.dump(__f,true)\n"
        "local __h=2166136261\n"
        "for __i=1,#__bc do\n"
        "  __h=((__h~__bc:byte(__i))*16777619)&4294967295\n"
        "end\n"
        "if __h~=%u then\n"
        "  local __trigger__=32767\n"
        "end\n",
        hash_val);

    int top = lua_gettop(L);

    /* 编译 */
    if (luaL_loadbuffer(L, src, strlen(src), "=integrity_check") != LUA_OK) {
        fprintf(stderr, "[integrity_check] compile: %s\n", lua_tostring(L, -1));
        lua_settop(L, top);
        return NULL;
    }

    /* string.dump */
    lua_getglobal(L, "string");
    lua_getfield(L, -1, "dump");
    lua_remove(L, -2);
    lua_pushvalue(L, -2);
    lua_pushboolean(L, 1);
    if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
        fprintf(stderr, "[integrity_check] dump: %s\n", lua_tostring(L, -1));
        lua_settop(L, top);
        return NULL;
    }

    /* luac.undump */
    lua_getglobal(L, "luac");
    lua_getfield(L, -1, "undump");
    lua_remove(L, -2);
    lua_pushvalue(L, -2);
    lua_pushboolean(L, 0);
    if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
        fprintf(stderr, "[integrity_check] undump: %s\n", lua_tostring(L, -1));
        lua_settop(L, top);
        return NULL;
    }

    /* 从 userdata 取出 Proto 并深拷贝 */
    luac_Proto *p = (luac_Proto *)luaL_checkudata(L, -1, "luac.Proto");
    if (!p) { lua_settop(L, top); return NULL; }

    luac_Proto *copy = calloc(1, sizeof(luac_Proto));
    copy->sizecode = p->sizecode;
    copy->code = malloc(sizeof(unsigned int) * p->sizecode);
    memcpy(copy->code, p->code, sizeof(unsigned int) * p->sizecode);

    copy->sizek = p->sizek;
    copy->k_tag = malloc(sizeof(int) * p->sizek);
    memcpy(copy->k_tag, p->k_tag, sizeof(int) * p->sizek);
    copy->k_num = malloc(sizeof(double) * p->sizek);
    memcpy(copy->k_num, p->k_num, sizeof(double) * p->sizek);
    copy->k_bool = malloc(sizeof(int) * p->sizek);
    memcpy(copy->k_bool, p->k_bool, sizeof(int) * p->sizek);
    copy->k_str = calloc(p->sizek, sizeof(char *));
    copy->k_str_len = calloc(p->sizek, sizeof(int));
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_str[i]) {
            int slen = p->k_str_len ? (p->k_str_len[i] < 0 ? -p->k_str_len[i] : p->k_str_len[i]) : (int)strlen(p->k_str[i]);
            copy->k_str[i] = malloc(slen + 1);
            memcpy(copy->k_str[i], p->k_str[i], slen);
            copy->k_str[i][slen] = '\0';
            copy->k_str_len[i] = slen;
        }
    }

    copy->sizep = 0;
    copy->p = NULL;
    copy->numparams = p->numparams;
    copy->is_vararg = p->is_vararg;
    copy->maxstacksize = p->maxstacksize;
    copy->linedefined = p->linedefined;
    copy->lastlinedefined = p->lastlinedefined;
    copy->code_tbl = LUA_NOREF;
    copy->k_tbl = LUA_NOREF;
    copy->p_tbl = LUA_NOREF;
    copy->lineinfo_tbl = LUA_NOREF;
    copy->locvars_tbl = LUA_NOREF;
    copy->upvalues_tbl = LUA_NOREF;

    /* 找到标记常量 32767，把加载它的 LOADK 指令替换成非法 opcode (op=47) */
    for (int i = 0; i < copy->sizek; i++) {
        if (copy->k_tag[i] == LUA_TNUMBER && copy->k_num[i] == 32767.0) {
            for (int j = 0; j < copy->sizecode; j++) {
                unsigned int ins = copy->code[j];
                int op = ins & 0x3F;
                int bx = (ins >> 14) & 0x3FFFF;
                if (op == 1 /* LOADK */ && bx == i) {
                    copy->code[j] = 47; /* 非法 opcode，VM 执行会崩溃 */
                    break;
                }
            }
            break;
        }
    }

    lua_settop(L, top);
    return copy;
}

/* 在主 proto 开头插入校验函数调用 */
static int inject_checker(luac_Proto *p, luac_Proto *checker) {
    int checker_idx = p->sizep;
    luac_Proto **new_p = realloc(p->p, sizeof(luac_Proto *) * (p->sizep + 1));
    if (!new_p) return -1;
    p->p = new_p;
    p->p[checker_idx] = checker;
    p->sizep++;

    int insert_count = 2;
    unsigned int *new_code = malloc(sizeof(unsigned int) * (p->sizecode + insert_count));
    if (!new_code) return -1;

    /* CLOSURE A=0 Bx=checker_idx (iABx) */
    new_code[0] = 44 | (0 << 6) | (checker_idx << 14);
    /* CALL A=0 B=1 C=1 (iABC) */
    new_code[1] = 36 | (0 << 6) | (1 << 14) | (1 << 23);

    memcpy(new_code + insert_count, p->code, sizeof(unsigned int) * p->sizecode);
    free(p->code);
    p->code = new_code;
    p->sizecode += insert_count;
    return 0;
}

int integrity_check_apply(lua_State *L, luac_Proto *p) {
    if (!p || p->sizecode == 0) return 0;
    unsigned int hash = hash_proto(p);
    luac_Proto *checker = compile_checker(L, hash);
    if (!checker) return -1;
    if (inject_checker(p, checker) != 0) {
        luac_free_proto(checker);
        return -1;
    }
    return 0;
}

int integrity_check_process(lua_State *L) {
    luac_Proto *p = (luac_Proto *)luaL_checkudata(L, 1, "luac.Proto");
    int ret = integrity_check_apply(L, p);
    lua_pushinteger(L, ret == 0 ? 1 : 0);
    return 1;
}
