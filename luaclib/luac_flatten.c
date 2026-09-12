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

#define UNCOND_END(op) ((op)==LUAC_OP_JMP||(op)==LUAC_OP_RETURN||(op)==LUAC_OP_TAILCALL||(op)==LUAC_OP_FORPREP)
#define COND_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET)
#define LOOP_OPS(op) ((op)==LUAC_OP_FORLOOP||op==LUAC_OP_FORPREP||op==LUAC_OP_TFORLOOP)
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

    /* Pre-pass: convert LOADBOOL C=1 to LOADBOOL C=0 + JMP, eliminating skip semantics */
    {
        int insert_count = 0;
        for (int i = 0; i < p->sizecode - 1; i++) {
            int op = p->code[i] & 0x3F;
            if (op == LUAC_OP_LOADBOOL) {
                int c = (p->code[i] >> 14) & 0x1FF;
                if (c != 0) insert_count++;
            }
        }
        if (insert_count > 0) {
            int new_size = p->sizecode + insert_count;
            unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * new_size);
            int *orig_to_new = (int *)malloc(sizeof(int) * (p->sizecode + 1));
            int *new_to_orig = (int *)malloc(sizeof(int) * new_size);
            int ni = 0;
            for (int i = 0; i < p->sizecode; i++) {
                orig_to_new[i] = ni;
                int op = p->code[i] & 0x3F;
                if (op == LUAC_OP_LOADBOOL) {
                    int c = (p->code[i] >> 14) & 0x1FF;
                    if (c != 0) {
                        int a = (p->code[i] >> 6) & 0xFF;
                        int b = (p->code[i] >> 23) & 0x1FF;
                        new_code[ni] = LUAC_ABC(LUAC_OP_LOADBOOL, a, b, 0);
                        new_to_orig[ni] = i;
                        ni++;
                        new_code[ni] = LUAC_AsBx(LUAC_OP_JMP, 0, 1);
                        new_to_orig[ni] = -1;
                        ni++;
                        continue;
                    }
                }
                new_code[ni] = p->code[i];
                new_to_orig[ni] = i;
                ni++;
            }
            orig_to_new[p->sizecode] = ni;
            for (int i = 0; i < ni; i++) {
                int op = new_code[i] & 0x3F;
                if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
                    int sbx = (int)(new_code[i] >> 14) - 131071;
                    int orig_i = new_to_orig[i];
                    if (orig_i >= 0) {
                        int orig_target = orig_i + sbx + 1;
                        if (orig_target >= 0 && orig_target <= p->sizecode) {
                            int new_target = orig_to_new[orig_target];
                            int new_sbx = new_target - i - 1;
                            new_code[i] = (new_code[i] & 0xFFF) | ((new_sbx + 131071) << 14);
                        }
                    }
                }
            }
            free(p->code);
            p->code = new_code;
            p->sizecode = ni;
            free(orig_to_new);
            free(new_to_orig);
        }
    }

    int n = p->sizecode;

    /* identify block starts */
    int *is_start = (int *)calloc(n + 2, sizeof(int));
    is_start[0] = 1;

    int *is_jmp_target = (int *)calloc(n + 2, sizeof(int));

    for (int i = 0; i < n; i++) {
        int op = p->code[i] & 0x3F;
        if (UNCOND_END(op) || LOOP_OPS(op) || COND_OPS(op)) {
            if (i + 1 < n) is_start[i + 1] = 1;
            if (IS_JUMP_TARGET(op)) {
                int sbx = (int)(p->code[i] >> 14) - 131071;
                int target = i + sbx + 1;
                if (target >= 0 && target < n) {
                    is_start[target] = 1;
                    is_jmp_target[target] = 1;
                }
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
    free(is_jmp_target);

    if (nblocks <= 2) {
        free(blocks);
        return;
    }


    int state_reg = p->maxstacksize;
    int cmp_reg = state_reg + 1; /* temp register for large-constant comparison */
    if (cmp_reg + 1 > 255) return;

    /* build new code */
    int max_new = n * 8 + nblocks * 6 + 64;
    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * max_new);
    int ni = 0;

    int *block_offsets = (int *)malloc(sizeof(int) * nblocks);
    int *dispatch_jmp_pos = (int *)malloc(sizeof(int) * nblocks);
    int *consumed = (int *)calloc(n + 1, sizeof(int)); /* 跨块消费的指令 */
    int *pos_map = (int *)malloc(sizeof(int) * (n + 1));
    for (int i = 0; i <= n; i++) pos_map[i] = -1;

    /* backward JMP records: (pos, target_block_id, orig_a) */
    int *back_jmp_pos = (int *)malloc(sizeof(int) * n);
    int *back_jmp_target = (int *)malloc(sizeof(int) * n);
    int *back_jmp_a = (int *)malloc(sizeof(int) * n);
    int back_jmp_count = 0;

    /* state-transition JMP records (preserve original A for close): (pos, orig_a) */
    int *state_jmp_pos = (int *)malloc(sizeof(int) * n);
    int *state_jmp_a = (int *)malloc(sizeof(int) * n);
    int state_jmp_count = 0;

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
                if (sbx < 0 && target_id >= 0) {
                    /* backward JMP: preserve to keep close-semantics, fix sBx later */
                    pos_map[i] = ni;
                    back_jmp_pos[back_jmp_count] = ni;
                    back_jmp_target[back_jmp_count] = target_id;
                    back_jmp_a[back_jmp_count] = (ins >> 6) & 0xFF;
                    back_jmp_count++;
                    new_code[ni++] = 0xDEAD; /* placeholder JMP */
                } else if (target_id >= 0) {
                    int kid = get_int_const(p, target_id);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, kid);
                    /* record JMP position and original A for close semantics */
                    state_jmp_pos[state_jmp_count] = ni;
                    state_jmp_a[state_jmp_count] = (ins >> 6) & 0xFF;
                    state_jmp_count++;
                    new_code[ni++] = 0xDEAD; /* JMP to dispatcher placeholder */
                } else {
                    pos_map[i] = ni;
                    new_code[ni++] = ins;
                    new_code[ni++] = 0xDEAD;
                }
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
                        free(pos_map); free(blocks);
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
                    pos_map[i] = ni;
                    new_code[ni++] = ins;
                }
            } else if (op == LUAC_OP_FORPREP) {
                /* 无条件循环跳转：保留 FORPREP，修正 sBx 指向目标块状态加载 */
                int fp_sbx = (int)(ins >> 14) - 131071;
                int fp_target_pos = i + fp_sbx + 1;
                int fp_target_id = block_id_at(blocks, nblocks, fp_target_pos);
                int fp_pos = ni;
                new_code[ni++] = ins; /* placeholder, sBx fixed below */
                if (fp_target_id >= 0) {
                    int kid = get_int_const(p, fp_target_id);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, kid);
                }
                new_code[ni++] = 0xDEAD;
                /* fix FORPREP sBx to point to target state load */
                int fp_new_sbx = (fp_target_id >= 0) ? (fp_pos + 1 - fp_pos - 1) : 0;
                new_code[fp_pos] = (ins & 0xFFF) | ((fp_new_sbx + 131071) << 14);
            } else if (op == LUAC_OP_FORLOOP || op == LUAC_OP_TFORLOOP) {
                /* 条件循环跳转：保留 FORLOOP/TFORLOOP，sBx 直接指向循环体块起始(向后跳转，保留close语义)
                   else 分支放在 FORLOOP 后面(fall through) */
                int loop_sbx = (int)(ins >> 14) - 131071;
                int loop_target_pos = i + loop_sbx + 1;
                int loop_target_id = block_id_at(blocks, nblocks, loop_target_pos);
                int loop_next_id = block_id_at(blocks, nblocks, i + 1);
                int loop_pos = ni;
                new_code[ni++] = ins; /* placeholder, sBx fixed later */
                /* record for backward jump fixup */
                if (loop_target_id >= 0) {
                    back_jmp_pos[back_jmp_count] = loop_pos;
                    back_jmp_target[back_jmp_count] = loop_target_id;
                    back_jmp_count++;
                }
                /* else branch: fall through to loop end */
                if (loop_next_id >= 0) {
                    int kid = get_int_const(p, loop_next_id);
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, kid);
                }
                new_code[ni++] = 0xDEAD;
            } else {
                pos_map[i] = ni;
                new_code[ni++] = ins;
            }
        }

        /* fall-through block: add state load for next block + JMP to dispatcher */
        int last_op = p->code[blocks[b].stop] & 0x3F;
        int block_empty = (ni == block_offsets[b]);
#if FLATTEN_DEBUG
        if (block_empty) FDBG("[flatten] block %d EMPTY - adding fallthrough\n", b);
#endif
        if (block_empty || (!UNCOND_END(last_op) && !COND_OPS(last_op) && last_op != LUAC_OP_FORLOOP && last_op != LUAC_OP_TFORLOOP)) {
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

    /* fixup backward JMPs and FORLOOPs (preserve close-semantics) */
    for (int i = 0; i < back_jmp_count; i++) {
        int pos = back_jmp_pos[i];
        int target_id = back_jmp_target[i];
        int target = block_offsets[target_id];
        int sbx = target - pos - 1;
        int op = new_code[pos] & 0x3F;
        if (op == LUAC_OP_FORLOOP || op == LUAC_OP_TFORLOOP) {
            new_code[pos] = (new_code[pos] & 0xFFF) | ((sbx + 131071) << 14);
        } else {
            int orig_a = back_jmp_a[i];
            new_code[pos] = LUAC_AsBx(LUAC_OP_JMP, orig_a, sbx);
        }
    }

    /* fixup 0xDEAD placeholders (JMP to dispatcher) */
    for (int i = 0; i < ni; i++) {
        if (new_code[i] == 0xDEAD) {
            int sbx = dispatcher_start - i - 1;
            new_code[i] = LUAC_AsBx(LUAC_OP_JMP, 0, sbx);
        }
    }

    /* fixup state-transition JMP A field (preserve close semantics) */
    for (int i = 0; i < state_jmp_count; i++) {
        int pos = state_jmp_pos[i];
        int orig_a = state_jmp_a[i];
        int sbx = (int)(new_code[pos] >> 14) - 131071;
        new_code[pos] = LUAC_AsBx(LUAC_OP_JMP, orig_a, sbx);
    }

    /* fixup FORPREP/FORLOOP/TFORLOOP sBx (原始位置 -> 新位置) */
    for (int i = 0; i < ni; i++) {
        int op = new_code[i] & 0x3F;
        if (op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP || op == LUAC_OP_TFORLOOP) {
            int old_sbx = (int)(new_code[i] >> 14) - 131071;
            /* 找到这条指令对应的原始位置 */
            int orig_pos = -1;
            for (int j = 0; j <= n; j++) {
                if (pos_map[j] == i) { orig_pos = j; break; }
            }
            if (orig_pos >= 0) {
                int target_orig = orig_pos + old_sbx + 1;
                if (target_orig >= 0 && target_orig <= n && pos_map[target_orig] >= 0) {
                    int new_sbx = pos_map[target_orig] - i - 1;
                    new_code[i] = (new_code[i] & 0xFFF) | ((new_sbx + 131071) << 14);
                }
            }
        }
    }
    free(pos_map);

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
    luac_sync_proto(L, 1);
    obf_invalidate_all_caches(L, p);

    /* heap-allocated to avoid WASM stack overflow */
    int cap = 1024;
    luac_Proto **list = luac_alloc(sizeof(luac_Proto *) * cap);
    int list_count = 0;
    luac_Proto **stk = luac_alloc(sizeof(luac_Proto *) * cap);
    int sp = 0;
    stk[sp++] = p;
    while (sp > 0) {
        if (list_count >= cap) {
            cap *= 2;
            list = realloc(list, sizeof(luac_Proto *) * cap);
            stk = realloc(stk, sizeof(luac_Proto *) * cap);
        }
        luac_Proto *cur = stk[--sp];
        list[list_count++] = cur;
        if (cur->p) for (int j = cur->sizep - 1; j >= 0; j--) stk[sp++] = cur->p[j];
    }

    for (int i = 0; i < list_count; i++) flatten_function(list[i]);
    lua_pushinteger(L, 1);
    return 1;
}
