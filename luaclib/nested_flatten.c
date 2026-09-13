/*
** nested_flatten.c - Nested Control Flow Flattening
**
** Requires luac_flatten to run first. Takes the single-layer state machine
** produced by luac_flatten and splits it into two nested layers:
**
**   outer_state  -> selects which inner-dispatcher (group) to run
**   state_reg    -> selects which block inside that group
**
** Blocks are randomly divided into 2 groups. Same-group transitions jump
** directly to the inner dispatcher; cross-group transitions set outer_state
** first and jump to the outer dispatcher.
**
** The decompiler must unwrap the outer state machine before it can even see
** the inner one, and the two state variables are coupled.
*/
#include <stdlib.h>
#include "obf_util.h"

#ifndef NESTED_DEBUG
#define NESTED_DEBUG 0
#endif
#if NESTED_DEBUG
#include <stdio.h>
#define NDBG(...) printf(__VA_ARGS__)
#else
#define NDBG(...)
#endif

/* ---- find_state_reg (same heuristic as flatten_enhance) ---- */
static int find_state_reg(luac_Proto *p) {
    unsigned char *is_jmp_target = (unsigned char *)calloc(p->sizecode + 1, 1);
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP ||
            op == LUAC_OP_TFORLOOP) {
            int sbx = (int)(p->code[i] >> 14) - 131071;
            int target = i + 1 + sbx;
            if (target >= 0 && target <= p->sizecode) is_jmp_target[target] = 1;
        }
    }
    int eq_counts[256] = {0};
    int loadk_at_target[256] = {0};
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_EQ) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (a == 1 && b < 256 && c >= 256 &&
                i + 1 < p->sizecode && (p->code[i+1] & 0x3F) == LUAC_OP_JMP)
                eq_counts[b]++;
        } else if (op == LUAC_OP_LOADK) {
            int a = (p->code[i] >> 6) & 0xFF;
            int bx = (p->code[i] >> 14) & 0x3FFFF;
            if (a < 256 && is_jmp_target[i] && bx < p->sizek &&
                (p->k_tag[bx] == LUA_TNUMINT ||
                 (p->k_tag[bx] == LUA_TNUMFLT && p->k_num[bx] == (long long)p->k_num[bx])))
                loadk_at_target[a]++;
        }
    }
    free(is_jmp_target);
    int best = -1, best_count = 0;
    for (int i = 0; i < 256; i++) {
        if (eq_counts[i] >= 2 && loadk_at_target[i] >= 2 && eq_counts[i] > best_count) {
            best_count = eq_counts[i]; best = i;
        }
    }
    return best;
}

static int get_int_const_idx(luac_Proto *p, long long val) {
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TNUMINT && p->k_int[i] == val) return i;
        if (p->k_tag[i] == LUA_TNUMFLT && p->k_num[i] == (double)val &&
            (double)val == (long long)val) return i;
    }
    return obf_add_k_integer(p, val);
}

static void nested_flatten_function(luac_Proto *p) {
    if (!p->code || p->sizecode < 10) return;
    int n = p->sizecode;

    int state_reg = find_state_reg(p);
    if (state_reg < 0) return; /* not flattened by luac_flatten */

    /* ---- locate dispatcher ---- */
    int disp_start = -1;
    for (int i = 0; i < n; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_EQ) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (a == 1 && b == state_reg && c >= 256 &&
                i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_JMP) {
                disp_start = i;
                break;
            }
        }
        /* LOADKX path: LOADKX + EXTRAARG + EQ(reg) + JMP */
        if (op == LUAC_OP_LOADKX && i + 3 < n &&
            (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG &&
            (p->code[i+2] & 0x3F) == LUAC_OP_EQ) {
            int a = (p->code[i+2] >> 6) & 0xFF;
            int b = (p->code[i+2] >> 23) & 0x1FF;
            int c = (p->code[i+2] >> 14) & 0x1FF;
            if (a == 1 && b == state_reg && c < 256 &&
                (p->code[i+3] & 0x3F) == LUAC_OP_JMP) {
                disp_start = i;
                break;
            }
        }
    }
    if (disp_start < 0) return;

    /* ---- parse dispatcher entries: state_id -> block target ---- */
    int cap = n;
    int *state_ids   = (int *)malloc(sizeof(int) * cap);
    int *block_tgt   = (int *)malloc(sizeof(int) * cap);
    int nstates = 0;
    int disp_end = disp_start;

    for (int i = disp_start; i < n; ) {
        int op = p->code[i] & 0x3F;
        long long sid = -1;
        int jmp_pos = -1;
        int entry_size = 0;

        if (op == LUAC_OP_EQ) {
            /* direct constant compare */
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (!(a == 1 && b == state_reg && c >= 256 &&
                  i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_JMP)) break;
            int kidx = c - 256;
            if (kidx >= p->sizek) break;
            if (!(p->k_tag[kidx] == LUA_TNUMINT || p->k_tag[kidx] == LUA_TNUMFLT)) break;
            sid = (p->k_tag[kidx] == LUA_TNUMINT) ? p->k_int[kidx] : (long long)p->k_num[kidx];
            jmp_pos = i + 1;
            entry_size = 2;
        } else if (op == LUAC_OP_LOADKX && i + 3 < n &&
                   (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG &&
                   (p->code[i+2] & 0x3F) == LUAC_OP_EQ) {
            /* LOADKX path */
            int a = (p->code[i+2] >> 6) & 0xFF;
            int b = (p->code[i+2] >> 23) & 0x1FF;
            int c = (p->code[i+2] >> 14) & 0x1FF;
            if (!(a == 1 && b == state_reg && c < 256 &&
                  (p->code[i+3] & 0x3F) == LUAC_OP_JMP)) break;
            int kidx = (int)(p->code[i+1] >> 6); /* EXTRAARG Ax */
            if (kidx >= p->sizek) break;
            if (!(p->k_tag[kidx] == LUA_TNUMINT || p->k_tag[kidx] == LUA_TNUMFLT)) break;
            sid = (p->k_tag[kidx] == LUA_TNUMINT) ? p->k_int[kidx] : (long long)p->k_num[kidx];
            jmp_pos = i + 3;
            entry_size = 4;
        } else {
            break;
        }

        int jmp_sbx = (int)(p->code[jmp_pos] >> 14) - 131071;
        int target = jmp_pos + 1 + jmp_sbx;
        state_ids[nstates] = (int)sid;
        block_tgt[nstates] = target;
        nstates++;
        disp_end = i + entry_size;
        i += entry_size;
    }
    if (nstates < 4) { free(state_ids); free(block_tgt); return; }

    /* ---- random 2-group split ---- */
    int *grp = (int *)malloc(sizeof(int) * nstates);
    for (int i = 0; i < nstates; i++) grp[i] = obf_rand() % 2;
    int g0 = 0, g1 = 0;
    for (int i = 0; i < nstates; i++) { if (grp[i] == 0) g0++; else g1++; }
    if (g0 == 0) grp[0] = 0;
    if (g1 == 0) grp[nstates - 1] = 1;

    NDBG("[nested] nstates=%d g0=%d g1=%d state_reg=%d disp=[%d..%d]\n",
         nstates, g0, g1, state_reg, disp_start, disp_end);

    /* helper: group of a state id */
    #define GRP_OF(sid) ({ int _g = 0; for (int _k = 0; _k < nstates; _k++) if (state_ids[_k]==(sid)) { _g = grp[_k]; break; } _g; })

    /* ---- outer state register ---- */
    int outer_reg = p->maxstacksize;
    if (outer_reg + 1 > 255) { free(state_ids); free(block_tgt); free(grp); return; }
    obf_ensure_stack(p, outer_reg + 1);

    /* ---- initial state id (from original first LOADK state_reg) ---- */
    int initial_sid = 0;
    if ((p->code[0] & 0x3F) == LUAC_OP_LOADK) {
        int a = (p->code[0] >> 6) & 0xFF;
        int bx = (p->code[0] >> 14) & 0x3FFFF;
        if (a == state_reg && bx < p->sizek &&
            (p->k_tag[bx] == LUA_TNUMINT || p->k_tag[bx] == LUA_TNUMFLT))
            initial_sid = (int)((p->k_tag[bx]==LUA_TNUMINT) ? p->k_int[bx] : p->k_num[bx]);
    }
    int initial_grp = GRP_OF(initial_sid);

    /* ---- build new code ---- */
    int max_new = n * 2 + nstates * 4 + 128;
    unsigned int *nc = (unsigned int *)malloc(sizeof(unsigned int) * max_new);
    int ni = 0;

    /* initial: outer_reg = group, state_reg = sid */
    nc[ni++] = LUAC_ABx(LUAC_OP_LOADK, outer_reg, get_int_const_idx(p, initial_grp));
    nc[ni++] = LUAC_ABx(LUAC_OP_LOADK, state_reg, get_int_const_idx(p, initial_sid));

    /* outer dispatcher */
    int outer_disp = ni;
    nc[ni++] = LUAC_ABC(LUAC_OP_EQ, 1, outer_reg, get_int_const_idx(p, 0) + LUAC_BITRK);
    int outer_jmp0 = ni; nc[ni++] = 0;
    nc[ni++] = LUAC_ABC(LUAC_OP_EQ, 1, outer_reg, get_int_const_idx(p, 1) + LUAC_BITRK);
    int outer_jmp1 = ni; nc[ni++] = 0;

    /* inner dispatcher 0 */
    int inner_disp0 = ni;
    int *ijmp0 = (int *)malloc(sizeof(int) * nstates);
    int nij0 = 0;
    int cmp_reg = state_reg + 1; /* temp register for LOADKX path, same as flatten */
    for (int i = 0; i < nstates; i++) {
        if (grp[i] != 0) continue;
        int kidx = get_int_const_idx(p, state_ids[i]);
        if (kidx <= 255) {
            nc[ni++] = LUAC_ABC(LUAC_OP_EQ, 1, state_reg, kidx + LUAC_BITRK);
        } else {
            nc[ni++] = LUAC_ABx(LUAC_OP_LOADKX, cmp_reg, 0);
            nc[ni++] = LUAC_Ax(LUAC_OP_EXTRAARG, kidx);
            nc[ni++] = LUAC_ABC(LUAC_OP_EQ, 1, state_reg, cmp_reg);
        }
        ijmp0[nij0++] = ni;
        nc[ni++] = 0;
    }

    /* inner dispatcher 1 */
    int inner_disp1 = ni;
    int *ijmp1 = (int *)malloc(sizeof(int) * nstates);
    int nij1 = 0;
    for (int i = 0; i < nstates; i++) {
        if (grp[i] != 1) continue;
        int kidx = get_int_const_idx(p, state_ids[i]);
        if (kidx <= 255) {
            nc[ni++] = LUAC_ABC(LUAC_OP_EQ, 1, state_reg, kidx + LUAC_BITRK);
        } else {
            nc[ni++] = LUAC_ABx(LUAC_OP_LOADKX, cmp_reg, 0);
            nc[ni++] = LUAC_Ax(LUAC_OP_EXTRAARG, kidx);
            nc[ni++] = LUAC_ABC(LUAC_OP_EQ, 1, state_reg, cmp_reg);
        }
        ijmp1[nij1++] = ni;
        nc[ni++] = 0;
    }

    /* ---- copy blocks (from disp_end), rewrite transitions ---- */
    int *pos_map = (int *)malloc(sizeof(int) * (n + 1));
    int *rev_pos_map = (int *)malloc(sizeof(int) * max_new);
    for (int i = 0; i <= n; i++) pos_map[i] = -1;
    for (int i = 0; i < max_new; i++) rev_pos_map[i] = -1;

    int cur_group = initial_grp;
    /* track which block we are inside */
    int cur_block_idx = -1;
    for (int i = 0; i < nstates; i++)
        if (block_tgt[i] == disp_end) { cur_block_idx = i; cur_group = grp[i]; break; }

    for (int i = disp_end; i < n; i++) {
        pos_map[i] = ni;

        /* update cur_block_idx when crossing a block target */
        for (int k = 0; k < nstates; k++) {
            if (block_tgt[k] == i) { cur_block_idx = k; cur_group = grp[k]; break; }
        }

        unsigned int ins = p->code[i];
        int op = ins & 0x3F;

        /* detect state assignment LOADK state_reg, K(sid) followed by JMP to dispatcher */
        if (op == LUAC_OP_LOADK) {
            int a = (ins >> 6) & 0xFF;
            int bx = (ins >> 14) & 0x3FFFF;
            if (a == state_reg && bx < p->sizek &&
                (p->k_tag[bx] == LUA_TNUMINT || p->k_tag[bx] == LUA_TNUMFLT) &&
                i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_JMP) {
                long long sid = (p->k_tag[bx]==LUA_TNUMINT) ? p->k_int[bx] : (long long)p->k_num[bx];
                int jmp_sbx = (int)(p->code[i+1] >> 14) - 131071;
                int target = (i+1) + 1 + jmp_sbx;
                if (target == disp_start) {
                    int orig_jmp_a = (p->code[i+1] >> 6) & 0xFF; /* preserve close level */
                    int sid_grp = GRP_OF((int)sid);
                    if (sid_grp == cur_group) {
                        int idisp = (cur_group == 0) ? inner_disp0 : inner_disp1;
                        int jsbx = idisp - ni - 2; /* JMP lands at ni+1 after LOADK write */
                        rev_pos_map[ni] = i;
                        nc[ni++] = ins;
                        nc[ni++] = LUAC_AsBx(LUAC_OP_JMP, orig_jmp_a, jsbx);
                        i++;
                        continue;
                    } else {
                        int jsbx = outer_disp - ni - 3;
                        nc[ni++] = LUAC_ABx(LUAC_OP_LOADK, outer_reg, get_int_const_idx(p, sid_grp));
                        rev_pos_map[ni] = i;
                        nc[ni++] = ins;
                        nc[ni++] = LUAC_AsBx(LUAC_OP_JMP, orig_jmp_a, jsbx);
                        i++;
                        continue;
                    }
                }
            }
        }

        rev_pos_map[ni] = i;
        nc[ni++] = ins;
    }
    pos_map[n] = ni;

    /* ---- fixup outer dispatcher JMPs ---- */
    nc[outer_jmp0] = LUAC_AsBx(LUAC_OP_JMP, 0, inner_disp0 - outer_jmp0 - 1);
    nc[outer_jmp1] = LUAC_AsBx(LUAC_OP_JMP, 0, inner_disp1 - outer_jmp1 - 1);

    /* ---- fixup inner dispatcher JMPs -> block new positions ---- */
    int ii = 0;
    for (int k = 0; k < nstates; k++) {
        if (grp[k] != 0) continue;
        int nt = pos_map[block_tgt[k]];
        if (nt >= 0) nc[ijmp0[ii]] = LUAC_AsBx(LUAC_OP_JMP, 0, nt - ijmp0[ii] - 1);
        ii++;
    }
    ii = 0;
    for (int k = 0; k < nstates; k++) {
        if (grp[k] != 1) continue;
        int nt = pos_map[block_tgt[k]];
        if (nt >= 0) nc[ijmp1[ii]] = LUAC_AsBx(LUAC_OP_JMP, 0, nt - ijmp1[ii] - 1);
        ii++;
    }

    /* ---- fixup JMPs inside blocks: use original position to compute target ---- */
    for (int i = 0; i < ni; i++) {
        if (rev_pos_map[i] < 0) continue; /* newly generated JMPs already correct */
        int orig_i = rev_pos_map[i];
        int op = nc[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP ||
            op == LUAC_OP_TFORLOOP) {
            int sbx = (int)(nc[i] >> 14) - 131071;
            int orig_target = orig_i + 1 + sbx;
            if (orig_target >= 0 && orig_target < n && pos_map[orig_target] >= 0) {
                int new_sbx = pos_map[orig_target] - i - 1;
                nc[i] = (nc[i] & 0x3FFFu) | (((unsigned int)(new_sbx + 131071) & 0x3FFFFu) << 14);
            }
        }
    }

    free(p->code);
    p->code = nc;
    p->sizecode = ni;
    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; p->sizelineinfo = 0; }

    free(state_ids); free(block_tgt); free(grp);
    free(ijmp0); free(ijmp1); free(pos_map); free(rev_pos_map);
    #undef GRP_OF
}

int nested_flatten_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

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
    for (int i = 0; i < list_count; i++) nested_flatten_function(list[i]);
    free(list); free(stk);

    lua_pushinteger(L, 1);
    return 1;
}
