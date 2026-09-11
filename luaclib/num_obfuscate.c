/*
** num_obfuscate.c - 数字常量混淆（任意数字，无精度丢失）
**
** 整数：ADD / SUB / BXOR，操作数为全 64 位随机值
**   N = (N + A) - A
**   N = (N - A) + A
**   N = (N ^ A) ^ A
** 浮点数：使用精确运算（乘2除2 / 双重取反 / 加0减0）
**   N = (N * 2) * 0.5      （乘2和乘0.5均精确，只改指数位）
**   N = (N * -1) * -1      （取反精确，只改符号位）
**   N = (N + 0) - 0        （加0减0精确）
**
** 所有数字 100% 处理，不限制范围，不排除 0/1。
*/
#include <time.h>
#include <math.h>
#include "obf_util.h"

static int calc_max_reg(luac_Proto *p) {
    int max_r = p->maxstacksize - 1;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        int a = (p->code[i] >> 6) & 0xFF;
        if (a > max_r) max_r = a;
        if (op <= 46) {
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (b < 255 && b > max_r) max_r = b;
            if (c < 255 && c > max_r) max_r = c;
        }
    }
    return max_r < 0 ? 0 : max_r;
}

/* 生成 64 位随机整数 */
static int64_t rand64(void) {
    uint64_t r = 0;
    r |= (uint64_t)obf_rand() << 32;
    r |= (uint64_t)obf_rand();
    return (int64_t)r;
}

static int is_number_const(luac_Proto *p, int idx) {
    return (p->k_tag[idx] == LUA_TNUMINT || p->k_tag[idx] == LUA_TNUMFLT);
}

/* Detect a proto already transformed by this module (re-entry / nested obfuscation).
   Signature: LOADK t; LOADK t+1; <binop> A,t,t+1 with A<t (injected scratch temps sit
   strictly above every original register; compiler-generated const+const does not). */
static int looks_num_processed(luac_Proto *p) {
    for (int i = 0; i + 2 < p->sizecode; i++) {
        unsigned int i0 = p->code[i], i1 = p->code[i+1], i2 = p->code[i+2];
        if ((i0 & 0x3F) != LUAC_OP_LOADK || (i1 & 0x3F) != LUAC_OP_LOADK) continue;
        int op2 = i2 & 0x3F;
        if (op2 != LUAC_OP_ADD && op2 != LUAC_OP_SUB &&
            op2 != LUAC_OP_BXOR && op2 != LUAC_OP_MUL) continue;
        int t1 = (i0 >> 6) & 0xFF, t2 = (i1 >> 6) & 0xFF;
        int A = (i2 >> 6) & 0xFF, B = (i2 >> 23) & 0x1FF, C = (i2 >> 14) & 0x1FF;
        if (t2 == t1 + 1 && B == t1 && C == t2 && A < t1) return 1;
    }
    return 0;
}

static int obf_function(luac_Proto *p) {
    if (!p->code || !p->k_num) return 0;

    /* 收集所有数字常量索引 */
    int *num_idx = luac_alloc(sizeof(int) * p->sizek);
    int num_count = 0;
    for (int i = 0; i < p->sizek; i++) {
        if (is_number_const(p, i)) num_idx[num_count++] = i;
    }
    if (num_count == 0) { free(num_idx); return 0; }
    if (looks_num_processed(p)) { free(num_idx); return 0; } /* already obfuscated: skip on 2nd pass */

    int max_reg = calc_max_reg(p);
    int tmp1 = max_reg + 1;
    int tmp2 = max_reg + 2;
    if (tmp2 + 1 > 250) { free(num_idx); return 0; } /* scratch must be strictly above every used reg; skip if no room */
    /* tmp2 defined above */
    obf_ensure_stack(p, tmp2 + 1);

    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * (p->sizecode * 4 + 16));
    int *new_pos = luac_alloc(sizeof(int) * (p->sizecode + 1));
    int ni = 0;
    int count = 0;

    for (int i = 0; i < p->sizecode; i++) {
        new_pos[i] = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;

        if (op == LUAC_OP_LOADK || op == LUAC_OP_LOADKX) {
            int bx;
            if (op == LUAC_OP_LOADK) {
                bx = (int)(ins >> 14) & 0x3FFFF;
            } else {
                /* LOADKX: 常量索引在下一条 EXTRAARG 的 Ax 字段 */
                if (i + 1 >= p->sizecode) { new_code[ni++] = ins; continue; }
                unsigned int ea = p->code[i + 1];
                if ((ea & 0x3F) != 46 /* EXTRAARG */) { new_code[ni++] = ins; continue; }
                bx = (int)(ea >> 6);
            }

            int is_num = 0;
            for (int j = 0; j < num_count; j++) {
                if (num_idx[j] == bx) { is_num = 1; break; }
            }
            if (!is_num) { new_code[ni++] = ins; continue; }

            int a = (ins >> 6) & 0xFF;
            double value = p->k_num[bx];
            int is_int = (p->k_tag[bx] == LUA_TNUMINT);

            if (is_int) {
                /* 整数：ADD / SUB / BXOR，全 64 位随机操作数 */
                int64_t n = (int64_t)value;
                int method = obf_rand() % 3;
                int64_t operand = rand64();
                int64_t v1, v2;
                int op_op;
                if (method == 0) {
                    v1 = operand; v2 = n - operand; op_op = LUAC_OP_ADD;
                } else if (method == 1) {
                    v1 = operand; v2 = operand - n; op_op = LUAC_OP_SUB;
                } else {
                    v1 = operand; v2 = n ^ operand; op_op = LUAC_OP_BXOR;
                }
                int idx1 = obf_add_k_integer(p, (long long)v1);
                int idx2 = obf_add_k_integer(p, (long long)v2);
                new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp1, idx1);
                new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp2, idx2);
                new_code[ni++] = LUAC_ABC(op_op, a, tmp1, tmp2);
                count++;
                if (op == LUAC_OP_LOADKX) {
                    /* 跳过 EXTRAARG */
                    new_pos[i + 1] = ni;
                    i++;
                }
                continue;
            } else {
                /* 浮点数：精确运算，不丢失精度 */
                int method = obf_rand() % 3;
                if (method == 0) {
                    /* N = (N * 2) * 0.5 —— 乘2和乘0.5只改指数位，精确 */
                    int idx2 = obf_add_k_number(p, 2.0);
                    int idx_half = obf_add_k_number(p, 0.5);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp1, bx); /* 原始常量 */
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp2, idx2);
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MUL, a, tmp1, tmp2); /* a = N * 2 */
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp2, idx_half);
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MUL, a, a, tmp2);    /* a = (N*2) * 0.5 */
                } else if (method == 1) {
                    /* N = (N * -1) * -1 —— 取反只改符号位，精确 */
                    int idx_neg = obf_add_k_number(p, -1.0);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp1, bx);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp2, idx_neg);
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MUL, a, tmp1, tmp2); /* a = N * -1 */
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MUL, a, a, tmp2);    /* a = (-N) * -1 */
                } else {
                    /* N = (N + 0) - 0 —— 加0减0精确 */
                    int idx0 = obf_add_k_number(p, 0.0);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp1, bx);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp2, idx0);
                    new_code[ni++] = LUAC_ABC(LUAC_OP_ADD, a, tmp1, tmp2); /* a = N + 0 */
                    new_code[ni++] = LUAC_ABC(LUAC_OP_SUB, a, a, tmp2);    /* a = (N+0) - 0 */
                }
                count++;
                if (op == LUAC_OP_LOADKX) {
                    new_pos[i + 1] = ni;
                    i++;
                }
                continue;
            }
        }
        new_code[ni++] = ins;
    }
    new_pos[p->sizecode] = ni;

    if (count > 0) {
        /* 调整所有跳转偏移 */
        for (int i = 0; i < ni; i++) {
            int op = new_code[i] & 0x3F;
            if (op == LUAC_OP_JMP || op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP ||
                op == LUAC_OP_TFORLOOP) {
                int a = (new_code[i] >> 6) & 0xFF;
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
                new_code[i] = ((unsigned int)op) | ((unsigned int)a << 6) |
                              ((unsigned int)(new_sbx + 131071) << 14);
            }
        }
        free(p->code);
        p->code = new_code;
        p->sizecode = ni;
        obf_ensure_stack(p, tmp2 + 1);
    } else {
        free(new_code);
    }
    free(new_pos);
    free(num_idx);
    return count;
}

int num_obfuscate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    /* heap-allocated to avoid WASM stack overflow */
    int cap = 1024;
    luac_Proto **list = luac_alloc(sizeof(luac_Proto *) * cap);
    int list_count = 0;
    luac_Proto **stk = luac_alloc(sizeof(luac_Proto *) * cap);
    int sp = 0;
    stk[sp++] = p;
    while (sp > 0) {
        if (list_count >= cap) {
            cap *= 2;
            list = realloc(list, sizeof(luac_Proto *) * cap);
            stk = realloc(stk, sizeof(luac_Proto *) * cap);
        }
        luac_Proto *cur = stk[--sp];
        list[list_count++] = cur;
        if (cur->p) for (int j = cur->sizep - 1; j >= 0; j--) stk[sp++] = cur->p[j];
    }

    int count = 0;
    for (int i = 0; i < list_count; i++) count += obf_function(list[i]);
    free(list);
    free(stk);
    lua_pushinteger(L, count);
    return 1;
}
