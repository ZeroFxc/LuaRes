/*
** opaque_junk.c - Dead junk branch injection (robust version)
**
** Injects unconditional JMP followed by junk instructions at random positions.
** The JMP always skips the junk, so junk is never executed.
** Junk can include arbitrary instructions (arithmetic, bitwise, etc.)
** because it is dead code.
**
** Pattern: JMP junk_size + [junk instructions]
*/
#include <time.h>
#include <stdlib.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET||(op)==LUAC_OP_LOADKX||(op)==LUAC_OP_TFORCALL)

static unsigned int make_junk_inst(luac_Proto *p, int high_reg, int extra) {
    int r = obf_rand() % 16;
    int reg = high_reg + (int)(obf_rand() % (extra > 0 ? extra : 1));
    int reg2 = high_reg + (int)(obf_rand() % (extra > 0 ? extra : 1));
    int kc = (p->sizek > 0) ? (int)(obf_rand() % p->sizek) : 0;
    switch (r) {
        case 0:  return LUAC_ABC(LUAC_OP_MOVE, reg, reg2, 0);
        case 1:  return LUAC_ABC(LUAC_OP_LOADBOOL, reg, obf_rand() % 2, 0);
        case 2:  return LUAC_ABC(LUAC_OP_NEWTABLE, reg, obf_rand() % 8, obf_rand() % 8);
        case 3:  return LUAC_ABC(LUAC_OP_LEN, reg, reg2, 0);
        case 4:  return LUAC_ABx(LUAC_OP_LOADK, reg, kc);
        case 5:  return LUAC_ABC(LUAC_OP_ADD, reg, reg2, reg2);
        case 6:  return LUAC_ABC(LUAC_OP_SUB, reg, reg2, reg2);
        case 7:  return LUAC_ABC(LUAC_OP_MUL, reg, reg2, reg2);
        case 8:  return LUAC_ABC(LUAC_OP_BXOR, reg, reg2, reg2);
        case 9:  return LUAC_ABC(LUAC_OP_BAND, reg, reg2, reg2);
        case 10: return LUAC_ABC(LUAC_OP_BOR, reg, reg2, reg2);
        case 11: return LUAC_ABC(LUAC_OP_UNM, reg, reg2, 0);
        case 12: return LUAC_ABC(LUAC_OP_BNOT, reg, reg2, 0);
        case 13: return LUAC_ABC(LUAC_OP_CONCAT, reg, reg2, reg2);
        case 14: { int skc = (kc < 256) ? kc : 0; return LUAC_ABC(LUAC_OP_GETTABLE, reg, reg2, skc + LUAC_BITRK); }
        default: return LUAC_ABC(LUAC_OP_SETTABLE, reg, reg2, reg2);
    }
}

static int inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 5 || count <= 0) return 0;
    /* B=0 instructions read to stack top — expanding maxstack injects extra values */
    for (int _si = 0; _si < p->sizecode; _si++) {
        int _op = p->code[_si] & 0x3F;
        if ((_op == 36 || _op == 37 || _op == 38 || _op == 45 || _op == 43) &&
            ((p->code[_si] >> 23) & 0x1FF) == 0) return 0;
    }
    int old_maxstack = p->maxstacksize;
    int extra = 12;
    if (old_maxstack + extra > 250) extra = 250 - old_maxstack;
    if (extra < 4) return 0; /* need scratch registers for junk */
    int high_reg = old_maxstack;
    obf_ensure_stack(p, old_maxstack + extra);

    /* add some constants for junk LOADK */
    for (int i = 0; i < 8; i++)
        obf_add_k_number(p, (double)(obf_rand() % 5000 - 2500));

    int injected = 0;
    int attempts = 0;
    while (injected < count && attempts < count * 20) {
        attempts++;
        int pos = 1 + (int)(obf_rand() % (p->sizecode - 1));
        if (pos > 0 && CONDITION_OPS(p->code[pos - 1] & 0x3F)) continue;
        /* LOADBOOL C>0 skips next instruction — inserting JMP here makes junk execute */
        if (pos > 0 && (p->code[pos - 1] & 0x3F) == 3 && ((p->code[pos - 1] >> 14) & 0x1FF) > 0) continue;
        int op = p->code[pos] & 0x3F;
        if (op == LUAC_OP_RETURN || op == LUAC_OP_EXTRAARG) continue;
        /* avoid CLOSURE + upvalue setup region */
        if (op == LUAC_OP_CLOSURE) continue;
        if (pos > 0 && (p->code[pos - 1] & 0x3F) == LUAC_OP_CLOSURE) continue;

        int junk_size = 4 + (int)(obf_rand() % 8); /* 4-11 */
        int branch_len = 1 + junk_size; /* JMP + junk */

        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + branch_len));
        memmove(&p->code[pos + branch_len], &p->code[pos],
                sizeof(unsigned int) * (p->sizecode - pos));

        /* unconditional JMP that skips the junk */
        p->code[pos] = LUAC_AsBx(LUAC_OP_JMP, 0, junk_size);
        /* junk instructions (never executed) */
        for (int j = 0; j < junk_size; j++)
            p->code[pos + 1 + j] = make_junk_inst(p, high_reg, extra);

        p->sizecode += branch_len;
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, branch_len);
        injected++;
    }

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;

    return injected;
}

int opaque_junk_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int count = 12;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }

    inject_function(p, count);

    if (p->p) {
        for (int i = 0; i < p->sizep; i++) {
            inject_function(p->p[i], count > 4 ? count / 2 : 3);
        }
    }

    lua_pushinteger(L, 1);
    return 1;
}
