/*
** num_obfuscate.c - Number constant obfuscation
** Replaces integer LOADK with LOADK+LOADK+ADD/SUB/BXOR
*/
#include <time.h>
#include "obf_util.h"

static int is_integer_const(luac_Proto *p, int idx) {
    if (p->k_tag[idx] != LUA_TNUMFLT && p->k_tag[idx] != LUA_TNUMINT) return 0;
    double v = p->k_num[idx];
    if (v != (double)(long long)v) return 0;
    long long n = (long long)v;
    return (n >= -1000000 && n <= 1000000 && n != 0 && n != 1);
}

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

static int obf_function(luac_Proto *p) {
    if (!p->code || !p->k_num) return 0;

    /* find number LOADKs */
    int *num_idx = luac_alloc(sizeof(int) * p->sizek);
    int num_count = 0;
    for (int i = 0; i < p->sizek; i++) {
        if (is_integer_const(p, i)) num_idx[num_count++] = i;
    }
    if (num_count == 0) { free(num_idx); return 0; }

    int max_reg = calc_max_reg(p);
    int tmp1 = max_reg + 2; if (tmp1 > 245) tmp1 = 245;
    int tmp2 = tmp1 + 1;

    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * (p->sizecode * 3 + 8));
    int ni = 0;
    int count = 0;

    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_LOADK) {
            int bx = (int)(p->code[i] >> 14);
            int is_num = 0;
            double value = 0;
            for (int j = 0; j < num_count; j++) {
                if (num_idx[j] == bx) { is_num = 1; value = p->k_num[bx]; break; }
            }
            if (is_num && (obf_rand() % 100) < 50) {
                int a = (p->code[i] >> 6) & 0xFF;
                int method = obf_rand() % 3;
                long long operand = 1 + (long long)(obf_rand() % 1000);
                long long v1, v2;
                int op_op;
                if (method == 0) { v1 = operand; v2 = (long long)value - operand; op_op = LUAC_OP_ADD; }
                else if (method == 1) { v1 = operand; v2 = (long long)value ^ operand; op_op = LUAC_OP_BXOR; }
                else { v1 = operand; v2 = operand - (long long)value; op_op = LUAC_OP_SUB; }

                int idx1 = obf_add_k_number(p, (double)v1);
                int idx2 = obf_add_k_number(p, (double)v2);
                new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp1, idx1);
                new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp2, idx2);
                new_code[ni++] = LUAC_ABC(op_op, a, tmp1, tmp2);
                count++;
                continue;
            }
        }
        new_code[ni++] = p->code[i];
    }

    if (count > 0) {
        free(p->code);
        p->code = new_code;
        p->sizecode = ni;
        obf_ensure_stack(p, tmp2 + 1);
    } else {
        free(new_code);
    }
    free(num_idx);
    return count;
}

int num_obfuscate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));

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

    int count = 0;
    for (int i = 0; i < list_count; i++) count += obf_function(list[i]);
    lua_pushinteger(L, count);
    return 1;
}
