/*
** luac_flatten.c - Control Flow Flattening (C implementation)
** Converts linear control flow into a state-machine dispatch loop.
** Skips functions containing loop opcodes (FORLOOP/FORPREP/TFORLOOP/TFORCALL).
*/
#include <time.h>
#include <stdlib.h>
#include "obf_util.h"

/* FLATTEN_DEBUG=1: print block structure, conditional handling, state machine */
#ifndef FLATTEN_DEBUG
#define FLATTEN_DEBUG 0
#endif
#if FLATTEN_DEBUG
#include <stdio.h>
#define FDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define FDBG(...)
#endif

#define UNCOND_END(op) ((op)==LUAC_OP_JMP||(op)==LUAC_OP_RETURN||(op)==LUAC_OP_TAILCALL)
#define COND_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET)
#define LOOP_OPS(op) ((op)==LUAC_OP_FORLOOP||op==LUAC_OP_FORPREP||op==LUAC_OP_TFORLOOP||op==LUAC_OP_TFORCALL)
#define IS_JUMP_TARGET(op) ((op)==LUAC_OP_JMP||(op)==LUAC_OP_FORLOOP||(op)==LUAC_OP_FORPREP||(op)==LUAC_OP_TFORLOOP)

typedef struct {
    int start;
    int stop;
    int id;
    int kind; /* 0=normal, 1=loop, 2=exit */
} Block;

static int get_int_const(luac_Proto *p, int val) {
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TNUMINT || p->k_tag[i] == LUA_TNUMFLT) && p->k_num[i] == (double)val)
            return i;
    }
    return obf_add_k_integer(p, (long long)val);
}

static int block_id_at(Block *blocks, int nblocks, int pos) {
    for (int i = 0; i < nblocks; i++) {
        if (pos >= blocks[i].start && pos <= blocks[i].stop) return blocks[i].id;
    }
    return -1;
}

static void flatten_function(luac_Proto *p) {
    if (!p->code || p->sizecode <= 3) return;
    int n = p->sizecode;

    /* identify block starts */
    int *is_start = (int *)calloc(n + 2, sizeof(int));
    is_start[0] = 1;

    for (int i = 0; i < n; i++) {
        int op = p->code[i] & 0x3F;
        if (UNCOND_END(op) || LOOP_OPS(op) || COND_OPS(op)) {
            if (i + 1 < n) is_start[i + 1] = 1;
            if (IS_JUMP_TARGET(op)) {
                int sbx = (int)(p->code[i] >> 14) - 131071;
                int target = i + sbx + 1;
                if (target >= 0 && target < n) is_start[target] = 1;
            }
        }
    }

    /* build blocks */
    Block *blocks = (Block *)malloc(sizeof(Block) * n);
    int nblocks = 0;
    int cur = 0;
    for (int i = 0; i < n; i++) {
        if (is_start[i] && i > cur) {
            blocks[nblocks].start = cur;
            blocks[nblocks].stop = i - 1;
            blocks[nblocks].id = nblocks;
            nblocks++;
            cur = i;
        }
    }
    blocks[nblocks].start = cur;
    blocks[nblocks].stop = n - 1;
    blocks[nblocks].id = nblocks;
    nblocks++;

    /* classify blocks */
    int has_loop = 0;
#if FLATTEN_DEBUG
    FDBG("[flatten] nblocks=%d, code size=%d\n", nblocks, n);
    for (int _db = 0; _db < nblocks; _db++) {
        FDBG("  block %d: [%d..%d]", blocks[_db].id, blocks[_db].start, blocks[_db].stop);
        for (int _di = blocks[_db].start; _di <= blocks[_db].stop; _di++) {
            int _op = p->code[_di] & 0x3F;
            const char *_names[] = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"};
            if (_di == blocks[_db].start) FDBG(" ops=");
            FDBG("%s ", _names[_op]);
        }
        FDBG("\n");
    }
#endif
    for (int b = 0; b < nblocks; b++) {
        blocks[b].kind = 0;
        for (int i = blocks[b].start; i <= blocks[b].stop; i++) {
            int op = p->code[i] & 0x3F;
            if (LOOP_OPS(op)) { blocks[b].kind = 1; has_loop = 1; break; }
            if (op == LUAC_OP_RETURN || op == LUAC_OP_TAILCALL) blocks[b].kind = 2;
            /* backward JMP indicates while/repeat loop */
            if (op == LUAC_OP_JMP) {
                int sbx = (int)(p->code[i] >> 14) - 131071;
                if (sbx < 0) { has_loop = 1; break; }
            }
        }
    }

    free(is_start);

    if (nblocks <= 2 || has_loop) {
#if FLATTEN_DEBUG
        FDBG("[flatten] SKIP: nblocks=%d has_loop=%d code_size=%d\n", nblocks, has_loop, n);
        for (int _di = 0; _di < n; _di++) {
            int _op = p->code[_di] & 0x3F;
            if (_op == 30 /* JMP */) {
                int _sbx = (int)(p->code[_di] >> 14) - 131071;
                FDBG("[flatten]   JMP at %d sbx=%d %s\n", _di, _sbx, _sbx < 0 ? "BACKWARD" : "forward");
            }
            if (_op >= 39 && _op <= 42) FDBG("[flatten]   LOOP_OP %d at %d\n", _op, _di);
        }
#endif
        free(blocks);
        return;
    }


    int state_reg = p->maxstacksize;
    int cmp_reg = state_reg + 1; /* temp register for large-constant comparison */

    /* build new code */
    int max_new = n * 8 + nblocks * 6 + 64;
    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * max_new);
    int ni = 0;

    int *block_offsets = (int *)malloc(sizeof(int) * nblocks);
    int *dispatch_jmp_pos = (int *)malloc(sizeof(int) * nblocks);
    int *consumed = (int *)calloc(n + 1, sizeof(int)); /* 跨块消费的指令 */

    /* initial state load */
    int first_k = get_int_const(p, blocks[0].id);
    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, first_k);

    int dispatcher_start = ni;

    /* dispatch table */
    for (int b = 0; b < nblocks; b++) {
        int kid = get_int_const(p, blocks[b].id);
#if FLATTEN_DEBUG
        FDBG("[flatten] dispatch block %d id=%d kid=%d %s\n", b, blocks[b].id, kid, kid > 255 ? "(LOADKX path)" : "(direct C)");
#endif
        if (kid <= 255) {
            new_code[ni++] = LUAC_ABC(LUAC_OP_EQ, 1, state_reg, kid + 0x100);
        } else {
            /* constant index > 255: load into temp register first, then compare registers */
            new_code[ni++] = LUAC_ABx(LUAC_OP_LOADKX, cmp_reg, 0);
            new_code[ni++] = LUAC_Ax(LUAC_OP_EXTRAARG, kid);
            new_code[ni++] = LUAC_ABC(LUAC_OP_EQ, 1, state_reg, cmp_reg);
        }
        dispatch_jmp_pos[b] = ni;
        new_code[ni++] = 0; /* placeholder JMP */
    }
#if FLATTEN_DEBUG
    FDBG("[flatten] sizek=%d state_reg=%d\n", p->sizek, state_reg);
#endif

    /* emit blocks */
    for (int b = 0; b < nblocks; b++) {
        block_offsets[b] = ni;

        for (int i = blocks[b].start; i <= blocks[b].stop; i++) {
            if (consumed[i]) continue;
            unsigned int ins = p->code[i];
            int op = ins & 0x3F;

            if (op == LUAC_OP_JMP) {
                int sbx = (int)(ins >> 14) - 131071;
                int target_pos = i + sbx + 1;
                int target_id = block_id_at(blocks, nblocks, target_pos);
#if FLATTEN_DEBUG
                FDBG("[flatten] JMP at block %d pos %d: sbx=%d target_pos=%d target_id=%d\n", b, i, sbx, target_pos, target_id);
#endif
                if (target_id >= 0) {
                    int kid = get_int_const(p, target_id);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, kid);
                } else {
                    new_code[ni++] = ins;
                }
                new_code[ni++] = 0xDEAD; /* JMP to dispatcher placeholder */
            } else if (COND_OPS(op)) {
                int jmp_idx = -1;
                if (i + 1 <= blocks[b].stop && (p->code[i + 1] & 0x3F) == LUAC_OP_JMP) {
                    jmp_idx = i + 1; /* JMP 在同一块内 */
                } else if (i == blocks[b].stop && b + 1 < nblocks &&
                           blocks[b + 1].start == i + 1 &&
                           (p->code[i + 1] & 0x3F) == LUAC_OP_JMP) {
                    jmp_idx = i + 1; /* JMP 在下一块开头 */
                    consumed[jmp_idx] = 1;
                }

                if (jmp_idx >= 0) {
                    unsigned int jmp_ins = p->code[jmp_idx];
                    int jmp_sbx = (int)(jmp_ins >> 14) - 131071;
                    int else_pos = jmp_idx + jmp_sbx + 1;
                    int else_id = block_id_at(blocks, nblocks, else_pos);
                    int then_id = block_id_at(blocks, nblocks, jmp_idx + 1);
#if FLATTEN_DEBUG
                    FDBG("[flatten] COND block=%d pos=%d jmp_idx=%d jmp_sbx=%d else_pos=%d else_id=%d then_id=%d\n",
                         b, i, jmp_idx, jmp_sbx, else_pos, else_id, then_id);
#endif
                    if (then_id < 0 || else_id < 0) {
#if FLATTEN_DEBUG
                        FDBG("[flatten] ABORT: invalid then_id/else_id at block=%d pos=%d\n", b, i);
#endif
                        free(new_code); free(block_offsets); free(dispatch_jmp_pos); free(consumed);
                        free(blocks);
                        return;
                    }

                    new_code[ni++] = ins;

                    int jmp_to_else_pos = ni;
                    new_code[ni++] = 0xBEEF; /* placeholder */

                    if (then_id >= 0) {
                        int kid = get_int_const(p, then_id);
                        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, kid);
                    }
                    new_code[ni++] = 0xDEAD;

                    int else_state_pos = ni;
                    if (else_id >= 0) {
                        int kid = get_int_const(p, else_id);
                        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, kid);
                    }
                    new_code[ni++] = 0xDEAD;

                    int sbx = else_state_pos - jmp_to_else_pos - 1;
                    new_code[jmp_to_else_pos] = LUAC_AsBx(LUAC_OP_JMP, 0, sbx);

                    i = jmp_idx; /* skip original JMP (for loop i++ moves past it) */
                } else {
                    new_code[ni++] = ins;
                }
            } else {
                new_code[ni++] = ins;
            }
        }

        /* fall-through block: add state load for next block + JMP to dispatcher */
        int last_op = p->code[blocks[b].stop] & 0x3F;
        int block_empty = (ni == block_offsets[b]);
#if FLATTEN_DEBUG
        if (block_empty) FDBG("[flatten] block %d EMPTY - adding fallthrough\n", b);
#endif
        if (block_empty || (!UNCOND_END(last_op) && !COND_OPS(last_op))) {
            int next_id = block_id_at(blocks, nblocks, blocks[b].stop + 1);
            if (next_id >= 0) {
                int kid = get_int_const(p, next_id);
                new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, kid);
                new_code[ni++] = 0xDEAD;
            }
        }
    }

    /* fixup dispatch table JMPs */
    for (int b = 0; b < nblocks; b++) {
        int target = block_offsets[b];
        int pos = dispatch_jmp_pos[b];
        int sbx = target - pos - 1;
        new_code[pos] = LUAC_AsBx(LUAC_OP_JMP, 0, sbx);
    }

    /* fixup 0xDEAD placeholders (JMP to dispatcher) */
    for (int i = 0; i < ni; i++) {
        if (new_code[i] == 0xDEAD) {
            int sbx = dispatcher_start - i - 1;
            new_code[i] = LUAC_AsBx(LUAC_OP_JMP, 0, sbx);
        }
    }

    free(p->code);
    p->code = new_code;
    p->sizecode = ni;
    obf_ensure_stack(p, cmp_reg + 1);

    free(blocks);
    free(block_offsets);
    free(dispatch_jmp_pos);
    free(consumed);
}

int luac_flatten_process(lua_State *L) {
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

    for (int i = 0; i < list_count; i++) flatten_function(list[i]);
    lua_pushinteger(L, 1);
    return 1;
}
