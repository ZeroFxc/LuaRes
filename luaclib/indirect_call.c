/*
** indirect_call.c - Indirect call obfuscation
**
** Before each CALL/TAILCALL, stores the function register into a temporary
** table and loads it back, making the call indirect:
**   NEWTABLE tbl
**   LOADK keyreg, K(0)
**   SETTABLE tbl, keyreg, func_reg     ; tbl[keyreg] = func
**   GETTABLE func_reg, tbl, keyreg     ; func = tbl[keyreg]
**   CALL func_reg, ...
**
** Uses high registers (beyond original maxstacksize). Key is loaded into
** a register (not RK constant) to avoid overflow when constant pool > 256.
*/
#include <time.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET||(op)==LUAC_OP_LOADKX||(op)==LUAC_OP_TFORCALL)

static void obfuscate_function(luac_Proto *p) {
    if (!p->code || p->sizecode < 3) return;

    int old_max = p->maxstacksize;
    int extra = 3; /* tbl, keyreg, spare */
    if (old_max + extra > 250) extra = 250 - old_max;
    if (extra < 2) return; /* need at least tbl + keyreg */
    int tbl_reg = old_max;
    int key_reg = old_max + 1;
    obf_ensure_stack(p, old_max + extra);

    int zero_idx = -1;
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TNUMINT || p->k_tag[i] == LUA_TNUMFLT) && p->k_num[i] == 0.0) {
            zero_idx = i; break;
        }
    }
    if (zero_idx < 0) zero_idx = obf_add_k_integer(p, 0);

    /* collect CALL/TAILCALL positions (reverse order) */
    int *call_pos = luac_alloc(sizeof(int) * p->sizecode);
    int ncall = 0;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_CALL || op == LUAC_OP_TAILCALL) {
            if (i > 0 && CONDITION_OPS(p->code[i - 1] & 0x3F)) continue;
            int a = (p->code[i] >> 6) & 0xFF;
            if (a >= old_max) continue;
            call_pos[ncall++] = i;
        }
    }

    for (int idx = ncall - 1; idx >= 0; idx--) {
        int pos = call_pos[idx];
        int func_a = (p->code[pos] >> 6) & 0xFF;

        int extra_n = 4;
        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + extra_n));
        memmove(&p->code[pos + extra_n], &p->code[pos],
                sizeof(unsigned int) * (p->sizecode - pos));

        p->code[pos]     = LUAC_ABC(LUAC_OP_NEWTABLE, tbl_reg, 0, 0);
        p->code[pos + 1] = LUAC_ABx(LUAC_OP_LOADK, key_reg, zero_idx);
        p->code[pos + 2] = LUAC_ABC(LUAC_OP_SETTABLE, tbl_reg, key_reg, func_a);
        p->code[pos + 3] = LUAC_ABC(LUAC_OP_GETTABLE, func_a, tbl_reg, key_reg);

        p->sizecode += extra_n;
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, extra_n);
    }

    free(call_pos);

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
}

int indirect_call_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    obfuscate_function(p);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        obfuscate_function(p->p[i]);

    lua_pushinteger(L, 1);
    return 1;
}
