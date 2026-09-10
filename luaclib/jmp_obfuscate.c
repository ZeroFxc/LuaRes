/*
** jmp_obfuscate.c - JMP offset obfuscation
**
** Inserts no-op JMP (sBx=0) chains before unconditional JMPs.
** Original JMP sBx is unchanged because both the JMP and its target
** shift by the same amount when instructions are inserted before it.
**
** Techniques (random per JMP):
**  0. 1x no-op prefix:  JMP+0, JMP N
**  1. 2x no-op prefix:  JMP+0, JMP+0, JMP N
**  2. 3x no-op prefix:  JMP+0, JMP+0, JMP+0, JMP N
**  3. Mixed: JMP+0, LOADBOOL(high), JMP+0, JMP N
**
** Only processes JMP that do NOT follow condition ops (EQ/LT/LE/TEST),
** because those JMPs are executed via donextjump and must remain
** immediately after the condition.
*/
#include <time.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET||(op)==LUAC_OP_LOADKX||(op)==LUAC_OP_TFORCALL||(op)==LUAC_OP_LOADBOOL)

static void obfuscate_function(luac_Proto *p) {
    if (!p->code || p->sizecode < 3) return;

    int old_max = p->maxstacksize;
    int extra = 4;
    if (old_max + extra > 250) extra = 250 - old_max;
    if (extra <= 0) extra = 1;
    int high_reg = old_max;
    obf_ensure_stack(p, old_max + extra);

    /* collect JMP positions (reverse order processing) */
    int *jmp_pos = luac_alloc(sizeof(int) * p->sizecode);
    int njmp = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_JMP) {
            int sbx = (int)((p->code[i] >> 14) & 0x3FFFF) - 131071;
            if (sbx > 0 && i > 0 && !CONDITION_OPS(p->code[i - 1] & 0x3F)) {
                jmp_pos[njmp++] = i;
            }
        }
    }

    for (int idx = njmp - 1; idx >= 0; idx--) {
        int pos = jmp_pos[idx];
        if (pos <= 0 || pos >= p->sizecode) continue;
        if (CONDITION_OPS(p->code[pos - 1] & 0x3F)) continue;

        int technique = obf_rand() % 4;
        int extra_n;
        if (technique == 0) extra_n = 1;
        else if (technique == 1) extra_n = 2;
        else if (technique == 2) extra_n = 3;
        else extra_n = 3; /* mixed: JMP+0, LOADBOOL, JMP+0 */

        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + extra_n));
        memmove(&p->code[pos + extra_n], &p->code[pos],
                sizeof(unsigned int) * (p->sizecode - pos));

        int ni = 0;
        if (technique == 3) {
            p->code[pos + ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, 0);
            p->code[pos + ni++] = LUAC_ABC(LUAC_OP_LOADBOOL, high_reg, obf_rand() % 2, 0);
            p->code[pos + ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, 0);
        } else {
            for (int i = 0; i < extra_n; i++)
                p->code[pos + ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, 0);
        }
        /* original JMP at pos+extra_n keeps its sBx unchanged */

        p->sizecode += extra_n;
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, extra_n);
    }

    free(jmp_pos);

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
}

int jmp_obfuscate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    obfuscate_function(p);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        obfuscate_function(p->p[i]);

    lua_pushinteger(L, 1);
    return 1;
}
