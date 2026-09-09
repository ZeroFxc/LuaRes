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
    /* 先扫描所有 CALL/TAILCALL，计算最大参数区结束位置，临时寄存器必须在参数区之外，
       否则插入的 NEWTABLE/LOADK/SETTABLE 会覆盖 CALL 参数值 */
    int max_arg_end = old_max - 1;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_CALL || op == LUAC_OP_TAILCALL) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            if (b > 0) {
                int arg_end = a + b - 1;  /* R[A+1..A+B-1] 最后一个参数 */
                if (arg_end > max_arg_end) max_arg_end = arg_end;
            }
        }
    }
    int tmp_base = max_arg_end + 1;
    int tbl_reg = tmp_base;
    int key_reg = tmp_base + 1;
    if (key_reg >= 253) return; /* register overflow (uint8 maxstacksize) */
    obf_ensure_stack(p, key_reg + 1);

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
            int b = (p->code[i] >> 23) & 0x1FF;
            if (a >= old_max) continue;
            if (b == 0) continue; /* B=0: args to top, cannot safely use temp regs */
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
