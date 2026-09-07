/*
** loop_restructure.c - 循环结构重构
**
** 核心思路：把代码中随机位置的直线指令片段包裹进 for i=1,1 循环。
** 循环体就是原始真实指令，执行一次，语义不变。
** 循环散布在函数各处，与正常代码交织，无法区分真假循环，难以批量移除。
**
** 包裹结构：
**   LOADK  R_tmp, 1
**   LOADK  R_tmp+1, 1
**   LOADK  R_tmp+2, 1
**   FORPREP R_tmp, sbx=body_len   -> 跳到 FORLOOP
**   [body: 原始指令 2~5 条]
**   FORLOOP R_tmp, sbx=-(body_len+1) -> 跳回 body 开头
**
** 只包裹"直线指令"片段（不含 JMP/条件跳转/RETURN/循环控制/EXTRAARG/LOADKX）。
*/
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "obf_util.h"

static int ensure_const_one(luac_Proto *p) {
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TNUMINT && p->k_num[i] == 1.0) return i;
        if (p->k_tag[i] == LUA_TNUMFLT && p->k_num[i] == 1.0) return i;
    }
    return obf_add_k_integer(p, 1);
}

/* 判断是否为可安全包裹的直线指令（不改变控制流，不依赖后续配对指令） */
static int is_plain_insn(unsigned int ins) {
    int op = ins & 0x3F;
    switch (op) {
        case 2:  /* LOADKX (必须跟 EXTRAARG) */
        case 30: /* JMP */
        case 31: /* EQ */
        case 32: /* LT */
        case 33: /* LE */
        case 34: /* TEST */
        case 35: /* TESTSET */
        case 37: /* TAILCALL */
        case 38: /* RETURN */
        case 39: /* FORLOOP */
        case 40: /* FORPREP */
        case 41: /* TFORCALL */
        case 42: /* TFORLOOP */
        case 46: /* EXTRAARG */
            return 0;
        default:
            return 1;
    }
}

/* 收集所有跳转目标 pc（0-based） */
static void collect_jump_targets(luac_Proto *p, char *targets) {
    for (int i = 0; i < p->sizecode; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int target = -1;
        if (op == 30 || op == 31 || op == 32 || op == 33) {
            int sbx = (int)((ins >> 14) & 0x3FFFF) - 131071;
            target = i + 1 + sbx;
        } else if (op == 34 || op == 35) {
            target = i + 2; /* TEST/TESTSET 后跟 JMP */
        } else if (op == 39 || op == 40 || op == 42) {
            int sbx = (int)((ins >> 14) & 0x3FFFF) - 131071;
            target = i + 1 + sbx;
        }
        if (target >= 0 && target < p->sizecode) {
            targets[target] = 1;
        }
    }
}

static int wrap_plain_segments(luac_Proto *p, int max_wraps) {
    if (!p->code || p->sizecode < 6) return 0;

    int one_idx = ensure_const_one(p);
    int old_maxstack = p->maxstacksize;
    int extra = 5;
    if (old_maxstack + extra > 250) extra = 250 - old_maxstack;
    if (extra < 4) return 0;
    int tmp_reg = old_maxstack;
    obf_ensure_stack(p, old_maxstack + extra);

    char *targets = (char *)calloc(p->sizecode + 16, 1);
    collect_jump_targets(p, targets);

    int wraps = 0;
    int i = 0;
    while (i < p->sizecode && wraps < max_wraps) {
        if (!is_plain_insn(p->code[i]) || targets[i]) {
            i++;
            continue;
        }
        int seg_start = i;
        while (i < p->sizecode && is_plain_insn(p->code[i]) && !targets[i]) {
            i++;
        }
        int seg_end = i;
        int seg_len = seg_end - seg_start;

        if (seg_len >= 4) {
            int offset = obf_rand() % (seg_len - 2);
            int max_body = seg_len - offset;
            if (max_body > 5) max_body = 5;
            int body_len = 2 + obf_rand() % (max_body - 1);
            if (body_len > seg_len - offset) body_len = seg_len - offset;
            if (body_len < 2) { i = seg_end; continue; }

            /* 0-based 位置 */
            int wrap_pos = seg_start + offset;
            int prefix_len = 4;

            unsigned int *prefix = (unsigned int *)malloc(sizeof(unsigned int) * prefix_len);
            int bi = 0;
            prefix[bi++] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, one_idx);
            prefix[bi++] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg + 1, one_idx);
            prefix[bi++] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg + 2, one_idx);
            prefix[bi++] = LUAC_AsBx(LUAC_OP_FORPREP, tmp_reg, body_len);

            /* obf_code_insert 是 1-based */
            obf_code_insert(p, wrap_pos + 1, prefix, prefix_len);
            free(prefix);

            /* 插入后 body 起始 = wrap_pos + prefix_len (0-based) */
            int forloop_pos = wrap_pos + prefix_len + body_len;
            unsigned int forloop_ins = LUAC_AsBx(LUAC_OP_FORLOOP, tmp_reg, -(body_len + 1));
            obf_code_insert(p, forloop_pos + 1, &forloop_ins, 1);

            /* 修正：插入 FORLOOP 时 obf_adjust_jumps_insert 会把 FORPREP 的 sbx 多 +1，
               这里直接重设为正确值 body_len（FORPREP 位置不变，仍在 wrap_pos+3） */
            p->code[wrap_pos + 3] = LUAC_AsBx(LUAC_OP_FORPREP, tmp_reg, body_len);

            wraps++;
            /* 重新收集跳转目标 */
            free(targets);
            targets = (char *)calloc(p->sizecode + 16, 1);
            collect_jump_targets(p, targets);
            i = forloop_pos + 1;
        }
    }

    free(targets);
    if (wraps > 0) {
        if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
        p->sizelineinfo = 0;
    }
    return wraps;
}

int loop_restructure_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    int max_wraps = 8;
    if (lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) max_wraps = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    int total = wrap_plain_segments(p, max_wraps);
    int sub_max = max_wraps > 1 ? max_wraps / 2 : 1;
    for (int i = 0; i < p->sizep; i++) {
        total += wrap_plain_segments(p->p[i], sub_max);
    }
    obf_invalidate_all_caches(L, p);
    lua_pushinteger(L, total);
    return 1;
}
