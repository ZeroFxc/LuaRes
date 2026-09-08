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

    {
        int i = 0;
        while (i < n) {
            int op = p->code[i] & 0x3F;
            if (op == LUAC_OP_TFORCALL) {
                group_size[i] = 1;
                group_start[i] = total;
                total += 1;
                i++;
            } else if (op == LUAC_OP_LOADKX && i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG) {
                /* LOADKX+EXTRAARG must stay consecutive: count as 2 "original" + JMP + extra */
                int brush = 5 + obf_rand() % 16;
                group_size[i] = 2 + 1 + 1 + brush;
                group_start[i] = total;
                total += group_size[i];
                i++;
                /* EXTRAARG is part of the LOADKX group */
                group_size[i] = 0;
                group_start[i] = group_start[i-1];
                i++;
            } else {
                int brush = 5 + obf_rand() % 16;
                group_size[i] = 1 + 1 + 1 + brush;
                group_start[i] = total;
                total += group_size[i];
                i++;
            }
        }
    }

    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * (total + 16));
    for (int _gi = total; _gi < total + 16; _gi++) new_code[_gi] = 0xDEADBEEF;
    int ni = 0;

    /* second pass: emit groups, fixup iAsBx */
    for (int i = 0; i < n; i++) {
        unsigned int inst = p->code[i];
        int op = inst & 0x3F;

        if (op == LUAC_OP_TFORCALL) {
            new_code[ni++] = inst;
            continue;
        }

        if (op == LUAC_OP_LOADKX && i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG) {
            /* emit LOADKX + EXTRAARG consecutively, then JMP + extra + brush */
            int brush = group_size[i] - 4; /* 2 original + 1 JMP + 1 extra = 4 */
            int logical = IS_LOGICAL(op);
            new_code[ni++] = inst; /* LOADKX */
            new_code[ni++] = p->code[i+1]; /* EXTRAARG */
            new_code[ni++] = make_jmp(brush + 1); /* JMP to skip extra+brush */
            if (logical) {
                new_code[ni++] = make_jmp(brush + 1); /* extra JMP for logical */
            } else {
                new_code[ni++] = random_inst(); /* garbage */
            }
            for (int j = 0; j < brush; j++) {
                new_code[ni++] = random_inst();
            }
            i++; /* skip EXTRAARG in the loop */
            continue;
        }

        int brush = group_size[i] - 3; /* original + JMP + extra = 3, rest is brush */
        int logical = IS_LOGICAL(op);

        /* fixup iAsBx before emitting */
        if (IS_ASBX(op)) {
            int old_sbx = (int)(inst >> 14) - 131071;
            int target_idx = i + old_sbx + 1;
            if (target_idx < 0 || target_idx >= n) {
#if OBF_DEBUG
                fprintf(stderr, "[OBF-PRE] idx=%d op=%d old_sbx=%d target_idx=%d n=%d\n", i, op, old_sbx, target_idx, n);
#endif
            }
            int new_target_pos;
            if (target_idx < 0) new_target_pos = 0;
            else if (target_idx >= n) new_target_pos = group_start[n-1]; /* past end = last instr (RETURN) */
            else new_target_pos = group_start[target_idx];
            int new_current_pos = group_start[i];
            int new_sbx = new_target_pos - new_current_pos - 1;
            inst = LUAC_AsBx(op, (inst >> 6) & 0xFF, new_sbx);
        }

        /* original instruction */
        new_code[ni++] = inst;
        /* JMP to skip garbage */
        new_code[ni++] = make_jmp(brush + 1);
        /* logical: extra JMP; non-logical: one random instruction */
        if (logical) {
            new_code[ni++] = make_jmp(brush + 1); /* at pos 2: target brush+4 = next group JMP, preserves conditional skip */
        } else {
            new_code[ni++] = random_inst();
        }
        /* brush random garbage */
        for (int j = 0; j < brush; j++) {
            new_code[ni++] = random_inst();
        }
    }

#if OBF_DEBUG
    if (ni != total) fprintf(stderr, "[OBF-GUARD] ni=%d total=%d MISMATCH\n", ni, total);
    for (int _gi = total; _gi < total + 16; _gi++) {
        if (new_code[_gi] != 0xDEADBEEF) {
            fprintf(stderr, "[OBF-GUARD] overflow at offset %d (word %d): %08x\n", _gi, _gi - total, new_code[_gi]);
        }
    }
#endif
    free(p->code);
    p->code = new_code;
    p->sizecode = ni;

#if OBF_DEBUG
    /* validation: check all ASBX targets */
    {
        int bad_jmp = 0;
        int orig_misaligned = 0;
        for (int vi = 0; vi < ni; vi++) {
            int vop = new_code[vi] & 0x3F;
            if (vop == 30 || vop == 39 || vop == 40 || vop == 42) {
                int vsbx = (int)((new_code[vi] >> 14) & 0x3FFFF) - 131071;
                int vtgt = vi + vsbx + 1;
                /* check if vi is a group start (original instruction position) */
                int is_orig_pos = 0;
                for (int gi = 0; gi < n; gi++) {
                    if (group_start[gi] == vi) { is_orig_pos = 1; break; }
                }
                if (vtgt < 0 || vtgt >= ni) {
                    fprintf(stderr, "[OBF-BAD] idx=%d op=%d sbx=%d target=%d range[0,%d] orig=%d\n", vi, vop, vsbx, vtgt, ni-1, is_orig_pos);
                    bad_jmp++;
                } else {
                    int is_start = 0;
                    for (int gi = 0; gi < n; gi++) {
                        if (group_start[gi] == vtgt) { is_start = 1; break; }
                    }
                    if (!is_start && is_orig_pos) {
                        /* original instruction's JMP targets non-group-start = BUG */
                        fprintf(stderr, "[OBF-ORIG-MISALIGNED] idx=%d op=%d sbx=%d target=%d\n", vi, vop, vsbx, vtgt);
                        orig_misaligned++;
                        bad_jmp++;
                    }
                }
            }
        }
        if (bad_jmp > 0 || orig_misaligned > 0)
            fprintf(stderr, "[OBF-VALIDATE] bad=%d orig_misaligned=%d (n=%d ni=%d)\n", bad_jmp, orig_misaligned, n, ni);
    }
#endif

#if OBF_DEBUG
    /* register bounds check */
    {
        int bad_reg = 0;
        for (int vi = 0; vi < ni; vi++) {
            unsigned int ins = new_code[vi];
            int vop = ins & 0x3F;
            int va = (ins >> 6) & 0xFF;
            int vb = (ins >> 23) & 0x1FF;
            int vc = (ins >> 14) & 0x1FF;
            if (va >= p->maxstacksize) {
                if (bad_reg < 5) fprintf(stderr, "[OBF-REG] idx=%d op=%d A=%d >= maxstack=%d\n", vi, vop, va, p->maxstacksize);
                bad_reg++;
            }
            if (vop != 30 && vop != 39 && vop != 40 && vop != 42 && vop != 43 && vop != 44 && vop != 45 && vop != 46 && vop != 47 && vop != 48) {
                if (vb < 256 && vb >= p->maxstacksize) {
                    if (bad_reg < 5) fprintf(stderr, "[OBF-REG] idx=%d op=%d B=%d(reg) >= maxstack=%d\n", vi, vop, vb, p->maxstacksize);
                    bad_reg++;
                }
                if (vc < 256 && vc >= p->maxstacksize) {
                    if (bad_reg < 5) fprintf(stderr, "[OBF-REG] idx=%d op=%d C=%d(reg) >= maxstack=%d\n", vi, vop, vc, p->maxstacksize);
                    bad_reg++;
                }
            }
        }
        if (bad_reg > 0) fprintf(stderr, "[OBF-REG] %d register overflows (maxstack=%d)\n", bad_reg, p->maxstacksize);
    }
#endif

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
