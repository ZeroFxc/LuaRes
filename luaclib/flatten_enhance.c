/*
** flatten_enhance.c - State machine dispatch enhancement
**
** Post-processes flattened code (after luac_flatten) to obfuscate the
** state variable transitions:
**
** 1. Arithmetic state assignment:
**    LOADK state, K(N)  →  LOADK state, K(a); ADD state, state, K(b)   (a+b=N)
**                           or LOADK state, K(a); SUB state, state, K(b)  (a-b=N)
**                           or LOADK state, K(a); BXOR state, state, K(b) (a^b=N)
**
** 2. XOR-obfuscated dispatch comparison:
**    EQ 1, state, K(N)  →  BXOR state,state,K(key); EQ 1,state,K(N^key);
**                           [JMP block]; BXOR state,state,K(key)
**
** Identifies state_reg by finding multiple EQ A=1 instructions that
** compare the same register register against integer constants.
*/
#include <time.h>
#include "obf_util.h"

static int find_state_reg(luac_Proto *p) {
    int counts[256];
    for (int i = 0; i < 256; i++) counts[i] = 0;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_EQ) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (a == 1 && b < 256 && c >= 256) counts[b]++;
        }
    }
    int best = -1, best_count = 0;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > best_count) { best_count = counts[i]; best = i; }
    }
    return (best_count >= 2) ? best : -1;
}

static int get_int_const_idx(luac_Proto *p, long long val) {
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TNUMINT && p->k_int[i] == val) return i;
        if ((p->k_tag[i] == LUA_TNUMFLT) && p->k_num[i] == (double)val && (double)val == (long long)val) return i;
    }
    return obf_add_k_integer(p, val);
}

static void obfuscate_function(luac_Proto *p) {
    if (!p->code || p->sizecode < 5) return;

    int state_reg = find_state_reg(p);
    if (state_reg < 0) return; /* not flattened */

    int old_max = p->maxstacksize;
    int extra = 2;
    if (old_max + extra > 250) extra = 250 - old_max;
    if (extra <= 0) extra = 1;
    int tmp_reg = old_max;
    obf_ensure_stack(p, old_max + extra);

    /* random XOR key for dispatch obfuscation */
    long long xor_key = (long long)(obf_rand() % 100000) + 1;
    int xor_key_idx = get_int_const_idx(p, xor_key);

    /* === Phase 1: replace LOADK state_reg, K(N) with arithmetic === */
    int *loadk_pos = luac_alloc(sizeof(int) * p->sizecode);
    int nloadk = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_LOADK) {
            int a = (p->code[i] >> 6) & 0xFF;
            if (a == state_reg) loadk_pos[nloadk++] = i;
        }
    }

    for (int idx = nloadk - 1; idx >= 0; idx--) {
        int pos = loadk_pos[idx];
        int bx = (p->code[pos] >> 14) & 0x3FFFF;
        if (bx >= p->sizek) continue;
        if (p->k_tag[bx] != LUA_TNUMINT && p->k_tag[bx] != LUA_TNUMFLT) continue;

        long long N;
        if (p->k_tag[bx] == LUA_TNUMINT) N = p->k_int[bx];
        else {
            double d = p->k_num[bx];
            if (d != (long long)d) continue; /* skip non-integer */
            N = (long long)d;
        }

        int method = obf_rand() % 3;
        long long a, b;
        int op;
        if (method == 0) {
            /* ADD: a + b = N */
            a = (long long)(obf_rand() % 200000) - 100000;
            b = N - a;
            op = LUAC_OP_ADD;
        } else if (method == 1) {
            /* SUB: a - b = N */
            a = (long long)(obf_rand() % 200000) - 100000;
            b = a - N;
            op = LUAC_OP_SUB;
        } else {
            /* BXOR: a ^ b = N */
            a = (long long)(obf_rand() % 200000) - 100000;
            b = a ^ N;
            op = LUAC_OP_BXOR;
        }

        int ka = get_int_const_idx(p, a);
        int kb = get_int_const_idx(p, b);

        if (kb <= 255) {
            /* replace 1 instruction with 2 */
            p->code[pos] = LUAC_ABx(LUAC_OP_LOADK, state_reg, ka);
            p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + 1));
            memmove(&p->code[pos + 2], &p->code[pos + 1],
                    sizeof(unsigned int) * (p->sizecode - pos - 1));
            p->code[pos + 1] = LUAC_ABC(op, state_reg, state_reg, kb + LUAC_BITRK);
            p->sizecode += 1;
            obf_adjust_jumps_insert(p->code, p->sizecode, pos + 2, 1);
        } else {
            /* constant index >255: load into temp register first */
            int tmp = state_reg + 1;
            obf_ensure_stack(p, tmp + 1);
            p->code[pos] = LUAC_ABx(LUAC_OP_LOADK, state_reg, ka);
            p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + 3));
            memmove(&p->code[pos + 4], &p->code[pos + 1],
                    sizeof(unsigned int) * (p->sizecode - pos - 1));
            p->code[pos + 1] = LUAC_ABx(LUAC_OP_LOADKX, tmp, 0);
            p->code[pos + 2] = LUAC_Ax(LUAC_OP_EXTRAARG, kb);
            p->code[pos + 3] = LUAC_ABC(op, state_reg, state_reg, tmp);
            p->sizecode += 3;
            obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, 3);
        }
    }
    free(loadk_pos);

    /* === Phase 2: XOR-obfuscate dispatch EQ comparisons === */
    /* DISABLED: has bug where JMP skips restore BXOR, state stays encrypted */
#if 0
    /* Find EQ 1, state_reg, K(N) followed by JMP — these are dispatch entries */
    int *eq_pos = luac_alloc(sizeof(int) * p->sizecode);
    int neq = 0;
    for (int i = 0; i < p->sizecode - 1; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_EQ) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (a == 1 && b == state_reg && c >= 256 &&
                (p->code[i + 1] & 0x3F) == LUAC_OP_JMP) {
                int cidx = c - 256;
                if (cidx < p->sizek && (p->k_tag[cidx] == LUA_TNUMINT || p->k_tag[cidx] == LUA_TNUMFLT))
                    eq_pos[neq++] = i;
            }
        }
    }

    for (int idx = neq - 1; idx >= 0; idx--) {
        int pos = eq_pos[idx];
        int c = (p->code[pos] >> 14) & 0x1FF;
        int cidx = c - 256;
        long long N;
        if (p->k_tag[cidx] == LUA_TNUMINT) N = p->k_int[cidx];
        else N = (long long)p->k_num[cidx];
        long long n_xor = N ^ xor_key;
        int nx_idx = get_int_const_idx(p, n_xor);

        /* save original JMP at pos+1 */
        unsigned int orig_jmp = p->code[pos + 1];

        /* Replace: EQ + JMP  →  BXOR + EQ + JMP(orig) + BXOR(restore)
           Insert 2 extra instructions */
        int extra_n = 2;
        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + extra_n));
        memmove(&p->code[pos + extra_n], &p->code[pos],
                sizeof(unsigned int) * (p->sizecode - pos));

        p->code[pos]     = LUAC_ABC(LUAC_OP_BXOR, state_reg, state_reg, xor_key_idx + LUAC_BITRK);
        p->code[pos + 1] = LUAC_ABC(LUAC_OP_EQ, 1, state_reg, nx_idx + LUAC_BITRK);
        p->code[pos + 2] = orig_jmp;  /* original dispatch JMP */
        p->code[pos + 3] = LUAC_ABC(LUAC_OP_BXOR, state_reg, state_reg, xor_key_idx + LUAC_BITRK);

        p->sizecode += extra_n;
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, extra_n);
    }
    free(eq_pos);
#endif

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
}

int flatten_enhance_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    obfuscate_function(p);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        obfuscate_function(p->p[i]);

    lua_pushinteger(L, 1);
    return 1;
}
