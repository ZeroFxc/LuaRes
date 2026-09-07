/*
** live_range_split.c - Live range splitting
** Saves a register's value to a high register, overwrites the original
** register with a dummy constant, then restores the original value.
** This splits the register's live range, making decompilation harder.
** Does NOT free lineinfo (causes use-after-free).
** Does NOT use obf_rand (memory-layout sensitive).
*/
#include "obf_util.h"

static int process_function(luac_Proto *p) {
    if (!p->code || p->sizecode < 4) return 0;
    if (p->is_vararg) return 0;

    int old_max = p->maxstacksize;
    if (old_max + 1 > 250) return 0; /* avoid unsigned char overflow */
    int high_reg = old_max;
    obf_ensure_stack(p, old_max + 1);

    /* add a zero constant for dummy overwrite */
    int zero_kidx = obf_add_k_number(p, 0.0);

    /* first pass: find LOADK targets and build new code */
    int *insert_pos = luac_alloc(sizeof(int) * p->sizecode);
    int *insert_len = luac_alloc(sizeof(int) * p->sizecode);
    memset(insert_pos, 0, sizeof(int) * p->sizecode);
    memset(insert_len, 0, sizeof(int) * p->sizecode);

    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * (p->sizecode * 4 + 64));
    int ni = 0;
    int count = 0;
    int inserted_so_far = 0;

    for (int i = 0; i < p->sizecode; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;

        insert_pos[i] = inserted_so_far;
        new_code[ni++] = ins;

        /* split after LOADK if target register is within original frame */
        if (op == LUAC_OP_LOADK && a < old_max && count < 8) {
            int seq_len = 3;
            /* MOVE high_reg, a — save original value */
            new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, high_reg, a, 0);
            /* LOADK a, zero — overwrite with dummy */
            new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, a, zero_kidx);
            /* MOVE a, high_reg — restore original value */
            new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, a, high_reg, 0);

            insert_len[i] = seq_len;
            inserted_so_far += seq_len;
            count++;
        } else {
            insert_len[i] = 0;
        }
    }

    /* second pass: adjust all jumps in one pass */
    {
        int total_inserted = inserted_so_far;
        for (int i = 0; i < ni; i++) {
            int jop = new_code[i] & 0x3F;
            if (jop != LUAC_OP_JMP && jop != LUAC_OP_FORLOOP &&
                jop != LUAC_OP_FORPREP && jop != LUAC_OP_TFORLOOP) continue;
            int sbx = (int)(new_code[i] >> 14) - 131071;
            int old_jmp = -1;
            for (int j = 0; j < p->sizecode; j++) {
                if (j + insert_pos[j] == i) { old_jmp = j; break; }
            }
            if (old_jmp < 0) continue; /* injected JMP, skip */
            int old_tgt = old_jmp + sbx + 1;
            int tgt_insert = (old_tgt >= 0 && old_tgt < p->sizecode) ? insert_pos[old_tgt] : total_inserted;
            int delta = tgt_insert - insert_pos[old_jmp];
            if (delta) {
                new_code[i] = (new_code[i] & 0x3FFF) | ((unsigned int)(sbx + delta + 131071) << 14);
            }
        }
    }

    free(p->code);
    p->code = new_code;
    p->sizecode = ni;

    free(insert_pos);
    free(insert_len);
    return count;
}

int live_range_split_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int count = 0;
    count += process_function(p);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        count += process_function(p->p[i]);

    lua_pushinteger(L, count);
    return 1;
}
