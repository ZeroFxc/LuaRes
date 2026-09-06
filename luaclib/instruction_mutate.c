/*
** instruction_mutate.c - Mutate instruction encodings
** 1. Commutative operand swap (ADD/MUL/EQ/BAND/BOR/BXOR)
** 2. Identity insertion: ADD A,A,Kst(0) after numeric result ops
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

static int get_zero_const(luac_Proto *p) {
    /* prefer integer 0 so identity ADD preserves integer type */
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TNUMINT && p->k_num[i] == 0.0) return i;
    }
    /* add integer zero constant */
    int idx = p->sizek;
    p->k_tag = realloc(p->k_tag, sizeof(int) * (p->sizek + 1));
    p->k_str = realloc(p->k_str, sizeof(char *) * (p->sizek + 1));
    p->k_str_len = realloc(p->k_str_len, sizeof(int) * (p->sizek + 1));
    p->k_num = realloc(p->k_num, sizeof(double) * (p->sizek + 1));
    p->k_bool = realloc(p->k_bool, sizeof(int) * (p->sizek + 1));
    p->k_tag[idx] = LUA_TNUMINT;
    p->k_str[idx] = NULL; p->k_str_len[idx] = 0;
    p->k_num[idx] = 0.0; p->k_bool[idx] = 0;
    p->sizek++;
    return idx;
}

static void insert_insn_at(luac_Proto *p, int pos, unsigned int insn) {
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + 1));
    memmove(&p->code[pos+1], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
    p->code[pos] = insn;
    p->sizecode++;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, 1);
}

static void mutate_function(luac_Proto *p) {
    if (!p->code || p->sizecode == 0) return;
    int zero_idx = get_zero_const(p);

    /* Pass 1: commutative operand swap (in-place, no length change) */
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (is_commutative(op) && (obf_rand() % 2 == 0)) {
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            int a = (p->code[i] >> 6) & 0xFF;
            p->code[i] = LUAC_ABC(op, a, c, b);
        }
    }

    /* Pass 2: identity insertion (iterate end-to-start to avoid index shift) */
    for (int i = p->sizecode - 1; i >= 0; i--) {
        int op = p->code[i] & 0x3F;
        if (is_numeric_result(op) && (obf_rand() % 4 == 0)) {
            int a = (p->code[i] >> 6) & 0xFF;
            if (a < p->maxstacksize) {
                insert_insn_at(p, i + 1, LUAC_ABC(LUAC_OP_ADD, a, a, zero_idx + BITRK));
            }
        }
    }
}

int instruction_mutate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));
    mutate_function(p);
    if (p->p) for (int i = 0; i < p->sizep; i++) mutate_function(p->p[i]);
    lua_pushinteger(L, 1);
    return 1;
}
