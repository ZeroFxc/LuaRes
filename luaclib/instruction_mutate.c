/*
** instruction_mutate.c - 指令变异（多变换模式）
**
** 1. 交换律操作数交换：ADD/MUL/EQ/BAND/BOR/BXOR
** 2. LT ↔ LE 互换：交换 B,C 并翻转 A 标志位
** 3. MOVE → 恒等运算：ADD/SUB/BXOR + K(0)
** 4. UNM → MUL + K(-1)
** 5. BNOT → BXOR + K(-1)
** 6. NOT → LOADBOOL(true) + TEST + LOADBOOL(false)
** 7. SUB → UNM(tmp,C) + ADD(A,B,tmp)
** 8. 数值结果后插入恒等运算：ADD 0 / SUB 0 / MUL 1 / BXOR 0 / BOR 0
*/
#include <time.h>
#include "obf_util.h"

#define BITRK 0x100

static int is_commutative(int op) {
    return op==LUAC_OP_ADD||op==LUAC_OP_MUL||op==LUAC_OP_EQ||
           op==LUAC_OP_BAND||op==LUAC_OP_BOR||op==LUAC_OP_BXOR;
}

static int is_numeric_result(int op) {
    return op==LUAC_OP_ADD||op==LUAC_OP_SUB||op==LUAC_OP_MUL||op==LUAC_OP_DIV||
           op==LUAC_OP_IDIV||op==LUAC_OP_MOD||op==LUAC_OP_POW||op==LUAC_OP_UNM||
           op==LUAC_OP_BNOT||op==LUAC_OP_BAND||op==LUAC_OP_BOR||op==LUAC_OP_BXOR||
           op==LUAC_OP_SHL||op==LUAC_OP_SHR||op==LUAC_OP_LEN;
}

static int ensure_int_const(luac_Proto *p, long long val) {
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TNUMINT && p->k_int[i] == val) return i;
    }
    return obf_add_k_integer(p, val);
}

static void mutate_function(luac_Proto *p) {
    if (!p->code || p->sizecode == 0) return;

    int k0 = ensure_int_const(p, 0);
    int k1 = ensure_int_const(p, 1);
    int km1 = ensure_int_const(p, -1);

    int tmp = p->maxstacksize;
    if (tmp > 248) tmp = 248;

    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * (p->sizecode * 4 + 64));
    int *new_pos = luac_alloc(sizeof(int) * (p->sizecode + 1));
    int ni = 0;

    for (int i = 0; i < p->sizecode; i++) {
        new_pos[i] = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;

        /* EXTRAARG 必须紧跟 LOADKX，原样输出不处理 */
        if (op == 46 /* EXTRAARG */) {
            new_code[ni++] = ins;
            continue;
        }

        int a = (ins >> 6) & 0xFF;
        int b = (ins >> 23) & 0x1FF;
        int c = (ins >> 14) & 0x1FF;

        /* LOADKX + EXTRAARG 对：不做插入类变换，只做交换律 */
        int is_loadkx = (op == 2 /* LOADKX */);

        /* 1. 交换律操作数交换（70%） */
        if (is_commutative(op) && (obf_rand() % 100) < 70) {
            ins = LUAC_ABC(op, a, c, b);
            int tmp_b = b; b = c; c = tmp_b;
        }

        /* 2. LT ↔ LE 互换（50%） */
        if ((op == LUAC_OP_LT || op == LUAC_OP_LE) && (obf_rand() % 100) < 50) {
            int new_op = (op == LUAC_OP_LT) ? LUAC_OP_LE : LUAC_OP_LT;
            int new_a = a ? 0 : 1;
            ins = LUAC_ABC(new_op, new_a, c, b);
            op = new_op; a = new_a;
        }

        int transformed = 0;

        /* 4. UNM → MUL + K(-1)（60%） */
        if (!transformed && op == LUAC_OP_UNM && (obf_rand() % 100) < 60 && b < 255) {
            new_code[ni++] = LUAC_ABC(LUAC_OP_MUL, a, b, km1 + BITRK);
            transformed = 1;
        }

        /* 5. BNOT → BXOR + K(-1)（60%） */
        if (!transformed && op == LUAC_OP_BNOT && (obf_rand() % 100) < 60 && b < 255) {
            new_code[ni++] = LUAC_ABC(LUAC_OP_BXOR, a, b, km1 + BITRK);
            transformed = 1;
        }

        /* 6. NOT → LOADBOOL + TEST + JMP + LOADBOOL（50%，A != B）
           此版本 TEST 不跳过时执行 donextjump，下一条必须是 JMP */
        if (!transformed && op == LUAC_OP_NOT && (obf_rand() % 100) < 50 && b < 255 && a != b) {
            /* NOT A,B: B falsy→A=true, B truthy→A=false
               LOADBOOL A, false   (初始 false)
               TEST B, 0, 1        (B falsy: skip JMP; B truthy: execute JMP)
               JMP +1              (B truthy: 跳过 LOADBOOL true; B falsy: 被 skip)
               LOADBOOL A, true    (B falsy: 执行→A=true; B truthy: 被跳过→A=false) */
            new_code[ni++] = LUAC_ABC(LUAC_OP_LOADBOOL, a, 0, 0);
            new_code[ni++] = LUAC_ABC(LUAC_OP_TEST, b, 0, 1);
            new_code[ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, 1);
            new_code[ni++] = LUAC_ABC(LUAC_OP_LOADBOOL, a, 1, 0);
            transformed = 1;
        }

        /* 7. SUB → UNM(tmp,C) + ADD(A,B,tmp)（35%） */
        if (!transformed && op == LUAC_OP_SUB && (obf_rand() % 100) < 35 &&
            b < 255 && c < 255 && tmp < 250 && !is_loadkx) {
            new_code[ni++] = LUAC_ABC(LUAC_OP_UNM, tmp, c, 0);
            new_code[ni++] = LUAC_ABC(LUAC_OP_ADD, a, b, tmp);
            transformed = 1;
        }

        if (!transformed) {
            new_code[ni++] = ins;
        }

        /* 8. 数值结果后插入恒等运算（25%，LOADKX 除外） */
        if (!is_loadkx && is_numeric_result(op) && (obf_rand() % 100) < 25 && a < 255) {
            int method = obf_rand() % 3;
            int op_op, kidx;
            if (method == 0) { op_op = LUAC_OP_ADD; kidx = k0; }
            else if (method == 1) { op_op = LUAC_OP_SUB; kidx = k0; }
            else { op_op = LUAC_OP_MUL; kidx = k1; }
            new_code[ni++] = LUAC_ABC(op_op, a, a, kidx + BITRK);
        }
    }
    new_pos[p->sizecode] = ni;

    /* 调整所有跳转偏移 */
    for (int i = 0; i < ni; i++) {
        int op = new_code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_TFORLOOP) {
            int ja = (new_code[i] >> 6) & 0xFF;
            int sbx = (int)(new_code[i] >> 14) - 131071;
            int orig_i = -1;
            for (int k = 0; k < p->sizecode; k++) {
                if (new_pos[k] == i) { orig_i = k; break; }
            }
            if (orig_i < 0) continue;
            int orig_target = orig_i + sbx + 1;
            if (orig_target < 0 || orig_target > p->sizecode) continue;
            int new_target = new_pos[orig_target];
            int new_sbx = new_target - i - 1;
            new_code[i] = ((unsigned int)op) | ((unsigned int)ja << 6) |
                          ((unsigned int)(new_sbx + 131071) << 14);
        }
    }

    free(p->code);
    p->code = new_code;
    p->sizecode = ni;
    if (tmp + 1 > p->maxstacksize) obf_ensure_stack(p, tmp + 1);
    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
    free(new_pos);
}

int instruction_mutate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    luac_Proto *list[8192];
    int list_count = 0;
    luac_Proto *stack[8192];
    int sp = 0;
    stack[sp++] = p;
    while (sp > 0 && list_count < 8192) {
        luac_Proto *cur = stack[--sp];
        list[list_count++] = cur;
        if (cur->p) for (int j = cur->sizep - 1; j >= 0; j--) stack[sp++] = cur->p[j];
    }

    for (int i = 0; i < list_count; i++) mutate_function(list[i]);
    lua_pushinteger(L, 1);
    return 1;
}
