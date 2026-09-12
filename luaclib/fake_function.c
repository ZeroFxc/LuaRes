/*
** fake_function.c - 伪造入口函数
**
** 把主 proto 的真实逻辑整体深拷贝到一个子 proto 中，
** 主 proto 替换为一段假的函数体（CLOSURE+CALL 真实逻辑 + 假计算 + RETURN）。
**
** 反编译主 proto 时，看到的是假函数体（一段无害的计算），
** 真实逻辑藏在被调用的子 proto 中。
**
** 运行时：主 proto 先通过 CLOSURE+CALL 执行真实逻辑（无返回值），
** 然后执行假计算并返回。主 chunk 的返回值通常被忽略，不影响运行。
*/
#include <stdlib.h>
#include <string.h>
#include "obf_util.h"

#define FAKE_FUNC_DEBUG 0
#if FAKE_FUNC_DEBUG
#define DBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define DBG(...) ((void)0)
#endif

/* 递归深拷贝 proto（包括子 proto）。返回新分配的 proto。 */
static luac_Proto *dup_proto(luac_Proto *src) {
    luac_Proto *dst = luac_alloc(sizeof(luac_Proto));
    memcpy(dst, src, sizeof(luac_Proto));

    /* 拷贝 code */
    if (src->code && src->sizecode > 0) {
        dst->code = malloc(sizeof(unsigned int) * src->sizecode);
        memcpy(dst->code, src->code, sizeof(unsigned int) * src->sizecode);
    } else { dst->code = NULL; dst->sizecode = 0; }

    /* 拷贝常量池 */
    if (src->sizek > 0) {
        dst->k_tag = malloc(sizeof(int) * src->sizek);
        memcpy(dst->k_tag, src->k_tag, sizeof(int) * src->sizek);
        dst->k_str = calloc(src->sizek, sizeof(char *));
        dst->k_str_len = malloc(sizeof(int) * src->sizek);
        dst->k_num = malloc(sizeof(double) * src->sizek);
        dst->k_bool = malloc(sizeof(int) * src->sizek);
        dst->k_int = malloc(sizeof(int64_t) * src->sizek);
        memcpy(dst->k_num, src->k_num, sizeof(double) * src->sizek);
        memcpy(dst->k_bool, src->k_bool, sizeof(int) * src->sizek);
        if (src->k_int) memcpy(dst->k_int, src->k_int, sizeof(int64_t) * src->sizek);
        else memset(dst->k_int, 0, sizeof(int64_t) * src->sizek);
        for (int i = 0; i < src->sizek; i++) {
            if ((src->k_tag[i] == LUA_TSHRSTR || src->k_tag[i] == LUA_TLNGSTR) && src->k_str[i]) {
                dst->k_str[i] = malloc(src->k_str_len[i] + 1);
                memcpy(dst->k_str[i], src->k_str[i], src->k_str_len[i]);
                dst->k_str[i][src->k_str_len[i]] = '\0';
                dst->k_str_len[i] = src->k_str_len[i];
            } else {
                dst->k_str[i] = NULL;
                dst->k_str_len[i] = 0;
            }
        }
    } else {
        dst->k_tag = NULL; dst->k_str = NULL; dst->k_str_len = NULL;
        dst->k_num = NULL; dst->k_bool = NULL; dst->k_int = NULL;
    }

    /* 递归拷贝子 proto */
    if (src->p && src->sizep > 0) {
        dst->p = malloc(sizeof(luac_Proto *) * src->sizep);
        for (int i = 0; i < src->sizep; i++)
            dst->p[i] = dup_proto(src->p[i]);
    } else { dst->p = NULL; dst->sizep = 0; }

    /* 拷贝调试信息 */
    DBG("[dup] lineinfo=%p sizelineinfo=%d sizelocvars=%d\n",
        (void*)src->lineinfo, src->sizelineinfo, src->sizelocvars);
    if (src->lineinfo && src->sizelineinfo > 0) {
        dst->lineinfo = malloc(sizeof(int) * src->sizelineinfo);
        memcpy(dst->lineinfo, src->lineinfo, sizeof(int) * src->sizelineinfo);
    } else { dst->lineinfo = NULL; dst->sizelineinfo = 0; }

    if (src->sizelocvars > 0) {
        dst->locvar_name = malloc(sizeof(char *) * src->sizelocvars);
        dst->locvar_name_len = malloc(sizeof(int) * src->sizelocvars);
        dst->locvar_startpc = malloc(sizeof(int) * src->sizelocvars);
        dst->locvar_endpc = malloc(sizeof(int) * src->sizelocvars);
        for (int i = 0; i < src->sizelocvars; i++) {
            int llen = src->locvar_name_len ? src->locvar_name_len[i] : 0;
            dst->locvar_name[i] = luac_strndup(src->locvar_name[i], llen);
            dst->locvar_name_len[i] = llen;
            dst->locvar_startpc[i] = src->locvar_startpc[i];
            dst->locvar_endpc[i] = src->locvar_endpc[i];
        }
    } else {
        dst->locvar_name = NULL; dst->locvar_name_len = NULL;
        dst->locvar_startpc = NULL; dst->locvar_endpc = NULL;
    }

    if (src->sizeupvalues > 0) {
        DBG("[dup] upval_name=%p upval_name_len=%p upval_instack=%p upval_idx=%p\n",
            (void*)src->upval_name, (void*)src->upval_name_len,
            (void*)src->upval_instack, (void*)src->upval_idx);
        dst->upval_name = malloc(sizeof(char *) * src->sizeupvalues);
        dst->upval_name_len = malloc(sizeof(int) * src->sizeupvalues);
        dst->upval_instack = malloc(sizeof(unsigned char) * src->sizeupvalues);
        dst->upval_idx = malloc(sizeof(unsigned char) * src->sizeupvalues);
        for (int i = 0; i < src->sizeupvalues; i++) {
            int ulen = src->upval_name_len ? src->upval_name_len[i] : 0;
            dst->upval_name[i] = luac_strndup(src->upval_name[i], ulen);
            dst->upval_name_len[i] = ulen;
            dst->upval_instack[i] = src->upval_instack[i];
            dst->upval_idx[i] = src->upval_idx[i];
        }
    } else {
        dst->upval_name = NULL; dst->upval_name_len = NULL;
        dst->upval_instack = NULL; dst->upval_idx = NULL;
    }

    if (src->source && src->source_len > 0) {
        dst->source = luac_strndup(src->source, src->source_len);
    } else { dst->source = NULL; dst->source_len = 0; }

    /* 清除缓存表引用（新 proto 没有缓存） */
    dst->code_tbl = LUA_NOREF;
    dst->k_tbl = LUA_NOREF;
    dst->p_tbl = LUA_NOREF;
    dst->lineinfo_tbl = LUA_NOREF;
    dst->locvars_tbl = LUA_NOREF;
    dst->upvalues_tbl = LUA_NOREF;

    return dst;
}

/* 构造假代码，返回指令数组和长度
 *
 * 注意：andlua 的 pushclosure 直接根据 proto 的 upvalue 描述符
 * （instack/idx）设置子闭包的 upvalues，CLOSURE 后面不需要
 * upvalue 设置指令（那些指令会被当作普通指令执行）。
 */
static unsigned int *build_fake_code(luac_Proto *p, luac_Proto *real_sub, int sub_idx, int *out_len) {
    int k1 = obf_add_k_number(p, 1.0);
    int k2 = obf_add_k_number(p, 2.0);
    int k3 = obf_add_k_number(p, 3.0);

    int n = 1 + 1 + 6 + 1; /* CLOSURE + CALL + 假计算 + RETURN */
    unsigned int *code = malloc(sizeof(unsigned int) * n);
    int pos = 0;

    code[pos++] = LUAC_ABx(LUAC_OP_CLOSURE, 0, sub_idx);
    code[pos++] = LUAC_ABC(LUAC_OP_CALL, 0, 1, 0);
    code[pos++] = LUAC_ABx(LUAC_OP_LOADK, 1, k1);
    code[pos++] = LUAC_ABx(LUAC_OP_LOADK, 2, k2);
    code[pos++] = LUAC_ABC(LUAC_OP_ADD, 1, 1, k2 + LUAC_BITRK);
    code[pos++] = LUAC_ABx(LUAC_OP_LOADK, 3, k3);
    code[pos++] = LUAC_ABC(LUAC_OP_MUL, 1, 1, 3);
    code[pos++] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);

    *out_len = pos;
    return code;
}

int fake_function_process(lua_State *L) {
    DBG("[fake_function] enter\n");
    luac_Proto *p = obf_check_proto(L);
    DBG("[fake_function] p=%p sizeupvalues=%d\n", (void*)p, p ? p->sizeupvalues : -1);
    obf_invalidate_all_caches(L, p);
    DBG("[fake_function] after invalidate\n");

    if (p->sizeupvalues < 1) {
        DBG("[fake_function] skip: no upvalues\n");
        lua_pushinteger(L, 0);
        return 1;
    }

    /* 1. 深拷贝主 proto 为子 proto */
    DBG("[fake_function] before dup_proto\n");
    luac_Proto *real_sub = dup_proto(p);
    DBG("[fake_function] after dup_proto real_sub=%p\n", (void*)real_sub);

    /* 子 proto 作为函数调用：无参数，非 vararg */
    real_sub->numparams = 0;
    real_sub->is_vararg = 0;

    /* real_sub 的 _ENV upvalue：从父 proto 的 upvalue 0 获取 */
    if (real_sub->sizeupvalues >= 1) {
        real_sub->upval_instack[0] = 0;
        real_sub->upval_idx[0] = 0;
    }

    DBG("[fake_function] real_sub: sizecode=%d sizek=%d sizep=%d maxstack=%d nup=%d\n",
        real_sub->sizecode, real_sub->sizek, real_sub->sizep,
        real_sub->maxstacksize, real_sub->sizeupvalues);

    /* 清除主 proto 原来的子 proto：假代码只调用 real_sub，原子 proto 不会被执行。
       保留它们会导致 vm_embed 序列化时，原子 proto 的 instack=1 upvalue
       引用主 proto 已不存在的寄存器（maxstacksize 被改为 4），造成越界。 */
    if (p->p_tbl != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, p->p_tbl);
        p->p_tbl = LUA_NOREF;
    }
    free(p->p);
    p->p = NULL;
    p->sizep = 0;

    /* 2. 把 real_sub 添加到主 proto（此时是唯一的子 proto，索引为 0） */
    int sub_idx = obf_add_subproto(L, p, real_sub);
    if (sub_idx < 0) {
        DBG("[fake_function] obf_add_subproto failed\n");
        lua_pushinteger(L, 0);
        return 1;
    }

    /* 3. 清空主 proto 原来的常量池：假代码只用到 1.0/2.0/3.0，
       保留原常量会让真代码的常量（print 等）暴露在主 proto 中。 */
    if (p->k_str) {
        for (int i = 0; i < p->sizek; i++) free(p->k_str[i]);
        free(p->k_str);
    }
    free(p->k_str_len);
    free(p->k_tag); free(p->k_num); free(p->k_bool);
    p->k_tag = NULL; p->k_str = NULL; p->k_str_len = NULL;
    p->k_num = NULL; p->k_bool = NULL;
    p->sizek = 0;

    /* 4. 构造假代码替换主 proto 的 code */
    int fake_len = 0;
    unsigned int *fake_code = build_fake_code(p, real_sub, sub_idx, &fake_len);

    /* 释放主 proto 原来的 code */
    free(p->code);
    p->code = fake_code;
    p->sizecode = fake_len;
    p->maxstacksize = 4;

    /* 4. 清除主 proto 的旧调试信息（code 已完全替换） */
    free(p->lineinfo); p->lineinfo = NULL; p->sizelineinfo = 0;
    free(p->locvar_name); p->locvar_name = NULL;
    free(p->locvar_name_len); p->locvar_name_len = NULL;
    free(p->locvar_startpc); p->locvar_startpc = NULL;
    free(p->locvar_endpc); p->locvar_endpc = NULL;
    p->sizelocvars = 0;

    obf_invalidate_all_caches(L, p);

    DBG("[fake_function] done: sub_idx=%d fake_len=%d\n", sub_idx, fake_len);

    lua_pushinteger(L, 1);
    return 1;
}
