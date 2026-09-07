/*
** luac_obfuscate.c - Instruction grouping with garbage padding (C implementation)
** Each instruction (except TFORCALL) becomes a group:
**   original + JMP(skip brush+1) + [extra JMP or random inst] + brush random instructions
** Logical opcodes (LOADBOOL/EQ/LT/LE/TEST/TESTSET) get extra JMP instead of random inst.
** iAsBx opcodes (JMP/FORLOOP/FORPREP/TFORLOOP) have sBx fixed up.
*/
#include <time.h>
#include <stdlib.h>
#include "obf_util.h"

#define IS_LOGICAL(op) ((op)==LUAC_OP_LOADBOOL||(op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET)
#define IS_ASBX(op) ((op)==LUAC_OP_JMP||(op)==LUAC_OP_FORLOOP||(op)==LUAC_OP_FORPREP||(op)==LUAC_OP_TFORLOOP)

static unsigned int make_jmp(int sbx) {
    return LUAC_AsBx(LUAC_OP_JMP, 0, sbx);
}

static unsigned int random_inst(void) {
    return (unsigned int)(obf_rand() % 0x100000000u);
}

static void handle_code(luac_Proto *p) {
    if (!p->code || p->sizecode == 0) return;
    int n = p->sizecode;

    /* first pass: compute group sizes and total new length */
    int *group_size = (int *)malloc(sizeof(int) * n);
    int *group_start = (int *)malloc(sizeof(int) * n);
    int total = 0;

    for (int i = 0; i < n; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_TFORCALL) {
            group_size[i] = 1;
        } else {
            int brush = 5 + obf_rand() % 16; /* 5-20 */
            /* original + JMP + (extra JMP or random) + brush */
            group_size[i] = 1 + 1 + 1 + brush;
        }
        group_start[i] = total;
        total += group_size[i];
    }

    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * total);
    int ni = 0;

    /* second pass: emit groups, fixup iAsBx */
    for (int i = 0; i < n; i++) {
        unsigned int inst = p->code[i];
        int op = inst & 0x3F;

        if (op == LUAC_OP_TFORCALL) {
            new_code[ni++] = inst;
            continue;
        }

        int brush = group_size[i] - 3; /* original + JMP + extra = 3, rest is brush */
        int logical = IS_LOGICAL(op);

        /* fixup iAsBx before emitting */
        if (IS_ASBX(op)) {
            int old_sbx = (int)(inst >> 14) - 131071;
            int target_idx = i + old_sbx + 1;
            if (target_idx >= 0 && target_idx < n) {
                int new_target_pos = group_start[target_idx];
                int new_current_pos = group_start[i];
                int new_sbx = new_target_pos - new_current_pos - 1;
                inst = LUAC_AsBx(op, (inst >> 6) & 0xFF, new_sbx);
            }
        }

        /* original instruction */
        new_code[ni++] = inst;
        /* JMP to skip garbage */
        new_code[ni++] = make_jmp(brush + 1);
        /* logical: extra JMP; non-logical: one random instruction */
        if (logical) {
            new_code[ni++] = make_jmp(brush + 1);
        } else {
            new_code[ni++] = random_inst();
        }
        /* brush random garbage */
        for (int j = 0; j < brush; j++) {
            new_code[ni++] = random_inst();
        }
    }

    free(p->code);
    p->code = new_code;
    p->sizecode = ni;
    free(group_size);
    free(group_start);
}

int luac_obfuscate_process(lua_State *L) {
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

    for (int i = 0; i < list_count; i++) handle_code(list[i]);
    lua_pushinteger(L, 1);
    return 1;
}
