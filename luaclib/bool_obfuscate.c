/*
** bool_obfuscate.c - Boolean constant and condition obfuscation
** Techniques: LOADBOOL inversion, comparison negation, TEST double negation
*/
#include <time.h>
#include "obf_util.h"

static int calc_max_reg(luac_Proto *p) {
    int max_r = 0;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        int a = (p->code[i] >> 6) & 0xFF;
        if (a > max_r) max_r = a;
        if (op != LUAC_OP_JMP && op != LUAC_OP_FORLOOP &&
            op != LUAC_OP_FORPREP && op != LUAC_OP_TFORLOOP) {
            int b = (p->code[i] >> 23) & 0x1FF;
            if (b < 256 && b > max_r) max_r = b;
        }
    }
    return max_r < 248 ? max_r : 248;
}

/* Technique 1: LOADBOOL true->not false, false->not true */
static int obf_loadbool(luac_Proto *p) {
    int count = 0;
    int orig_code = p->sizecode;
    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * (orig_code * 2 + 8));
    int *insert_pos = (int *)calloc(orig_code + 1, sizeof(int));
    int ni = 0;
    int inserted = 0;
    for (int i = 0; i < orig_code; i++) {
        insert_pos[i] = inserted;
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_LOADBOOL) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            int is_cmp_pattern = 0;
            if (i > 0 && (p->code[i-1] & 0x3F) == LUAC_OP_LOADBOOL) {
                int prev_c = (p->code[i-1] >> 14) & 0x1FF;
                if (prev_c == 1) is_cmp_pattern = 1;
            }
            if (c == 0 && !is_cmp_pattern && (obf_rand() % 100) < 50) {
                new_code[ni++] = LUAC_ABC(LUAC_OP_LOADBOOL, a, 1 - b, 0);
                new_code[ni++] = LUAC_ABC(LUAC_OP_NOT, a, a, 0);
                inserted++;
                count++;
                continue;
            }
        }
        new_code[ni++] = p->code[i];
    }
    insert_pos[orig_code] = inserted;
    if (count > 0) {
        /* single-pass jump adjustment */
        for (int j = 0; j < ni; j++) {
            int op = new_code[j] & 0x3F;
            if (op == LUAC_OP_JMP || op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP || op == LUAC_OP_TFORLOOP) {
                int a = (new_code[j] >> 6) & 0xFF;
                int sbx = (int)(new_code[j] >> 14) - 131071;
                int orig_i = -1;
                for (int k = 0; k < orig_code; k++) {
                    if (k + insert_pos[k] == j) { orig_i = k; break; }
                }
                if (orig_i < 0) continue;
                int orig_target = orig_i + sbx + 1;
                int new_target;
                if (orig_target >= orig_code) new_target = orig_code + inserted;
                else if (orig_target < 0) continue;
                else new_target = orig_target + insert_pos[orig_target];
                int new_sbx = new_target - j - 1;
                new_code[j] = ((unsigned int)op) | ((unsigned int)a << 6) | ((unsigned int)(new_sbx + 131071) << 14);
            }
        }
        free(p->code);
        p->code = new_code;
        p->sizecode = ni;
    } else {
        free(new_code);
    }
    free(insert_pos);
    return count;
}

/* Technique 2: Comparison negation (LT/LE/EQ + JMP + false(skip) + true) */
static int obf_comparison(luac_Proto *p) {
    int count = 0;
    int orig_code = p->sizecode;
    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * (orig_code * 2 + 8));
    int *insert_pos = (int *)calloc(orig_code + 1, sizeof(int));
    int ni = 0;
    int inserted = 0;
    int i = 0;
    while (i < orig_code) {
        insert_pos[i] = inserted;
        if (i + 3 < orig_code) {
            int op1 = p->code[i] & 0x3F;
            if ((op1 == LUAC_OP_EQ || op1 == LUAC_OP_LT || op1 == LUAC_OP_LE) &&
                (p->code[i+1] & 0x3F) == LUAC_OP_JMP) {
                int sbx = (int)(p->code[i+1] >> 14) - 131071;
                if (sbx == 1 &&
                    (p->code[i+2] & 0x3F) == LUAC_OP_LOADBOOL &&
                    (p->code[i+3] & 0x3F) == LUAC_OP_LOADBOOL) {
                    int a3 = (p->code[i+2] >> 6) & 0xFF;
                    int b3 = (p->code[i+2] >> 23) & 0x1FF;
                    int c3 = (p->code[i+2] >> 14) & 0x1FF;
                    int a4 = (p->code[i+3] >> 6) & 0xFF;
                    int b4 = (p->code[i+3] >> 23) & 0x1FF;
                    int c4 = (p->code[i+3] >> 14) & 0x1FF;
                    if (b3 == 0 && c3 == 1 && b4 == 1 && c4 == 0 && a3 == a4 &&
                        (obf_rand() % 100) < 50) {
                        int a1 = (p->code[i] >> 6) & 0xFF;
                        int b1 = (p->code[i] >> 23) & 0x1FF;
                        int c1 = (p->code[i] >> 14) & 0x1FF;
                        new_code[ni++] = LUAC_ABC(op1, 1 - a1, b1, c1);
                        new_code[ni++] = p->code[i+1];
                        new_code[ni++] = p->code[i+2];
                        new_code[ni++] = p->code[i+3];
                        new_code[ni++] = LUAC_ABC(LUAC_OP_NOT, a3, a3, 0);
                        inserted++;
                        count++;
                        insert_pos[i+1] = inserted;
                        insert_pos[i+2] = inserted;
                        insert_pos[i+3] = inserted;
                        i += 4;
                        continue;
                    }
                }
            }
        }
        new_code[ni++] = p->code[i];
        i++;
    }
    insert_pos[orig_code] = inserted;
    if (count > 0) {
        for (int j = 0; j < ni; j++) {
            int op = new_code[j] & 0x3F;
            if (op == LUAC_OP_JMP || op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP || op == LUAC_OP_TFORLOOP) {
                int a = (new_code[j] >> 6) & 0xFF;
                int sbx = (int)(new_code[j] >> 14) - 131071;
                int orig_i = -1;
                for (int k = 0; k < orig_code; k++) {
                    if (k + insert_pos[k] == j) { orig_i = k; break; }
                }
                if (orig_i < 0) continue;
                int orig_target = orig_i + sbx + 1;
                int new_target;
                if (orig_target >= orig_code) new_target = orig_code + inserted;
                else if (orig_target < 0) continue;
                else new_target = orig_target + insert_pos[orig_target];
                int new_sbx = new_target - j - 1;
                new_code[j] = ((unsigned int)op) | ((unsigned int)a << 6) | ((unsigned int)(new_sbx + 131071) << 14);
            }
        }
        free(p->code);
        p->code = new_code;
        p->sizecode = ni;
    } else {
        free(new_code);
    }
    free(insert_pos);
    return count;
}

/* Technique 3: TEST double negation */
static int obf_test(luac_Proto *p) {
    int count = 0;
    int orig_code = p->sizecode;
    int high_reg = calc_max_reg(p) + 2;
    if (high_reg > 249) return 0; /* scratch must stay above used range and <=249; skip if no room */
    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * (orig_code * 2 + 8));
    int *insert_pos = (int *)calloc(orig_code + 1, sizeof(int));
    int ni = 0;
    int inserted = 0;
    for (int i = 0; i < orig_code; i++) {
        insert_pos[i] = inserted;
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_TEST && i + 1 < orig_code &&
            (p->code[i+1] & 0x3F) == LUAC_OP_JMP &&
            (obf_rand() % 100) < 30) {
            int a = (p->code[i] >> 6) & 0xFF;
            int c = (p->code[i] >> 14) & 0x1FF;
            new_code[ni++] = LUAC_ABC(LUAC_OP_NOT, high_reg, a, 0);
            new_code[ni++] = LUAC_ABC(LUAC_OP_TEST, high_reg, 0, 1 - c);
            inserted++;
            count++;
            continue;
        }
        new_code[ni++] = p->code[i];
    }
    insert_pos[orig_code] = inserted;
    if (count > 0) {
        for (int j = 0; j < ni; j++) {
            int op = new_code[j] & 0x3F;
            if (op == LUAC_OP_JMP || op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP || op == LUAC_OP_TFORLOOP) {
                int a = (new_code[j] >> 6) & 0xFF;
                int sbx = (int)(new_code[j] >> 14) - 131071;
                int orig_i = -1;
                for (int k = 0; k < orig_code; k++) {
                    if (k + insert_pos[k] == j) { orig_i = k; break; }
                }
                if (orig_i < 0) continue;
                int orig_target = orig_i + sbx + 1;
                int new_target;
                if (orig_target >= orig_code) new_target = orig_code + inserted;
                else if (orig_target < 0) continue;
                else new_target = orig_target + insert_pos[orig_target];
                int new_sbx = new_target - j - 1;
                new_code[j] = ((unsigned int)op) | ((unsigned int)a << 6) | ((unsigned int)(new_sbx + 131071) << 14);
            }
        }
        free(p->code);
        p->code = new_code;
        p->sizecode = ni;
        obf_ensure_stack(p, high_reg + 1);
    } else {
        free(new_code);
    }
    free(insert_pos);
    return count;
}

static int obf_function(luac_Proto *p) {
    int total = 0;
    total += obf_comparison(p);
    total += obf_loadbool(p);
    total += obf_test(p);
    if (p->p) for (int i = 0; i < p->sizep; i++) total += obf_function(p->p[i]);
    return total;
}

int bool_obfuscate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    int count = obf_function(p);
    lua_pushinteger(L, count);
    return 1;
}
