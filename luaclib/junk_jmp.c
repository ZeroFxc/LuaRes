/*
** junk_jmp.c - JMP 垃圾指令注入（多样化模式）
**
** 4 种模式混合，消除 sbx=0 特征：
** A. JMP 跳过垃圾块（前向，sbx>0）
** B. JMP 链（多个 JMP 互相跳转）
** C. 假后向 JMP（假循环体，内含 sbx<0 但被外层 JMP 跳过）
** D. 条件跳转垃圾（EQ/LT/LE 恒真/恒假 + JMP）
**
** 垃圾块内使用合法 opcode（MOVE/LOADK/算术等），用高寄存器
*/
#include <time.h>
#include <stdlib.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET||(op)==LUAC_OP_LOADKX||(op)==LUAC_OP_TFORCALL||(op)==LUAC_OP_CLOSURE)

static unsigned int make_legit_junk(luac_Proto *p, int high_reg, int extra) {
    int r = obf_rand() % 12;
    int reg = high_reg + (int)(obf_rand() % (extra > 0 ? extra : 1));
    int reg2 = high_reg + (int)(obf_rand() % (extra > 0 ? extra : 1));
    int kc = (p->sizek > 0) ? (int)(obf_rand() % p->sizek) : 0;
    switch (r) {
        case 0:  return LUAC_ABC(LUAC_OP_MOVE, reg, reg2, 0);
        case 1:  return LUAC_ABC(LUAC_OP_LOADBOOL, reg, obf_rand() % 2, 0);
        case 2:  return LUAC_ABx(LUAC_OP_LOADK, reg, kc);
        case 3:  return LUAC_ABC(LUAC_OP_ADD, reg, reg2, reg2);
        case 4:  return LUAC_ABC(LUAC_OP_SUB, reg, reg2, reg2);
        case 5:  return LUAC_ABC(LUAC_OP_MUL, reg, reg2, reg2);
        case 6:  return LUAC_ABC(LUAC_OP_BXOR, reg, reg2, reg2);
        case 7:  return LUAC_ABC(LUAC_OP_BAND, reg, reg2, reg2);
        case 8:  return LUAC_ABC(LUAC_OP_BOR, reg, reg2, reg2);
        case 9:  return LUAC_ABC(LUAC_OP_UNM, reg, reg2, 0);
        case 10: return LUAC_ABC(LUAC_OP_LEN, reg, reg2, 0);
        default: return LUAC_ABC(LUAC_OP_NEWTABLE, reg, obf_rand() % 4, obf_rand() % 4);
    }
}

static int is_safe_pos(luac_Proto *p, int pos) {
    if (pos <= 0 || pos >= p->sizecode) return 0;
    int prev_op = p->code[pos-1] & 0x3F;
    if (CONDITION_OPS(prev_op)) return 0;
    /* LOADBOOL with C!=0 skips the NEXT instruction (compiler idiom).
       Inserting here would let the junk body execute after the skip. */
    if (prev_op == LUAC_OP_LOADBOOL && (((p->code[pos-1] >> 14) & 0x1FF) != 0)) return 0;
    if (prev_op == 43 && ((p->code[pos-1] >> 14) & 0x1FF) == 0) return 0;
    /* Open-vararg live window: after VARARG with B==0, slots R[a..top-1] are live
       (top can exceed maxstacksize) until consumed by CALL/TAILCALL/RETURN/SETLIST.
       Junk inside the window clobbers live vararg slots. */
    {
        int scan = pos - 1;
        while (scan >= 0) {
            int sop = p->code[scan] & 0x3F;
            if (sop == 36 || sop == 37 || sop == 38 || sop == 43) break; /* consumed */
            if (sop == 45 && (((p->code[scan] >> 23) & 0x1FF) == 0)) return 0; /* VARARG B==0 */
            if (sop == 36 && (((p->code[scan] >> 23) & 0x1FF) == 0) &&
                             (((p->code[scan] >> 14) & 0x1FF) == 0)) return 0; /* CALL B==0,C==0 */
            scan--;
        }
    }
    int op = p->code[pos] & 0x3F;
    if (op == LUAC_OP_JMP || op == LUAC_OP_RETURN || op == LUAC_OP_EXTRAARG) return 0;
    if (op == LUAC_OP_CLOSURE) return 0;
    return 1;
}

/* 模式 A: JMP 跳过垃圾块 (1 + junk_size 条指令) */
static int inject_pattern_A(luac_Proto *p, int pos, int high_reg, int extra) {
    int junk_size = 3 + (int)(obf_rand() % 8); /* 3-10 */
    int total = 1 + junk_size;
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + total));
    memmove(&p->code[pos + total], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
    p->code[pos] = LUAC_AsBx(LUAC_OP_JMP, 0, junk_size);
    for (int j = 0; j < junk_size; j++)
        p->code[pos + 1 + j] = make_legit_junk(p, high_reg, extra);
    p->sizecode += total;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, total);
    return total;
}

/* 模式 B: JMP 链 (3 个 JMP 互相跳转, 共 3 条指令) */
static int inject_pattern_B(luac_Proto *p, int pos) {
    int total = 3;
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + total));
    memmove(&p->code[pos + total], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
    /* JMP -> 第3条 JMP -> 下一条真实指令 */
    p->code[pos]     = LUAC_AsBx(LUAC_OP_JMP, 0, 2); /* 跳到 pos+2 */
    p->code[pos + 1] = LUAC_AsBx(LUAC_OP_JMP, 0, 1); /* 跳到 pos+2 (死代码,永不执行) */
    p->code[pos + 2] = LUAC_AsBx(LUAC_OP_JMP, 0, 1); /* 跳到下一条真实指令 */
    p->sizecode += total;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, total);
    return total;
}

/* 模式 C: 假后向 JMP (假循环体)
   JMP sBx=body_len+1  跳过整个假循环
   [body_len 条垃圾指令]
   JMP sBx=-(body_len+1)  看起来像跳回循环开头 (但永远不执行)
*/
static int inject_pattern_C(luac_Proto *p, int pos, int high_reg, int extra) {
    int body_len = 4 + (int)(obf_rand() % 6); /* 4-9 */
    int total = 1 + body_len + 1; /* 外层JMP + body + 后向JMP */
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + total));
    memmove(&p->code[pos + total], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
    p->code[pos] = LUAC_AsBx(LUAC_OP_JMP, 0, body_len + 1); /* 跳过 body + 后向JMP */
    for (int j = 0; j < body_len; j++)
        p->code[pos + 1 + j] = make_legit_junk(p, high_reg, extra);
    /* 后向 JMP: 从 pos+1+body_len 跳回 pos+1, sBx = -(body_len+1) */
    p->code[pos + 1 + body_len] = LUAC_AsBx(LUAC_OP_JMP, 0, -(body_len + 1));
    p->sizecode += total;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, total);
    return total;
}

/* 模式 D: 条件跳转垃圾 (恒真条件 + JMP)
   LOADK Rn, 0
   EQ Rn, Rn, 0   (0 == 0 恒真)
   JMP sBx=junk_size
   [junk_size 条垃圾]
*/
static int inject_pattern_D(luac_Proto *p, int pos, int high_reg, int extra) {
    int junk_size = 2 + (int)(obf_rand() % 5); /* 2-6 */
    int total = 3 + junk_size; /* LOADK + EQ + JMP + junk */
    /* 需要一个常量 0 */
    int k0 = -1;
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == 3 && p->k_num[i] == 0.0) { k0 = i; break; }
    }
    if (k0 < 0) {
        obf_add_k_number(p, 0.0);
        k0 = p->sizek - 1;
    }
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + total));
    memmove(&p->code[pos + total], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
    p->code[pos]     = LUAC_ABx(LUAC_OP_LOADK, high_reg, k0);
    p->code[pos + 1] = LUAC_ABC(LUAC_OP_EQ, 1, high_reg, high_reg); /* 0==0 恒真, A=1 跳过下条JMP如果不跳 */
    p->code[pos + 2] = LUAC_AsBx(LUAC_OP_JMP, 0, junk_size);
    for (int j = 0; j < junk_size; j++)
        p->code[pos + 3 + j] = make_legit_junk(p, high_reg, extra);
    p->sizecode += total;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, total);
    return total;
}

static int inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 5 || count <= 0) return 0;

    int old_maxstack = p->maxstacksize;
    int extra = 8;
    if (old_maxstack + extra > 245) extra = 245 - old_maxstack;
    if (extra < 3) return 0;
    int high_reg = old_maxstack;
    obf_ensure_stack(p, old_maxstack + extra);

    int injected = 0;
    int attempts = 0;
    while (injected < count && attempts < count * 15) {
        attempts++;
        int pos = 1 + (int)(obf_rand() % (p->sizecode - 1));
        if (!is_safe_pos(p, pos)) continue;

        int mode = obf_rand() % 4;
        int used = 0;
        switch (mode) {
            case 0: used = inject_pattern_A(p, pos, high_reg, extra); break;
            case 1: used = inject_pattern_B(p, pos); break;
            case 2: used = inject_pattern_C(p, pos, high_reg, extra); break;
            case 3: used = inject_pattern_D(p, pos, high_reg, extra); break;
        }
        if (used > 0) injected++;
    }

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
    return injected;
}

int junk_jmp_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int count = 40;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }

    int n = inject_function(p, count);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        n += inject_function(p->p[i], count > 5 ? count / 2 : 5);

    lua_pushinteger(L, n);
    return 1;
}
