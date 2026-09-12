/*
** indirect_dispatch.c - Indirect State Dispatch via Lookup Table
**
** Requires luac_flatten (and optionally flatten_enhance) to run first.
**
** Every state assignment "LOADK state_reg, K(N)" is replaced by a table
** lookup: state_reg = decode_table[hash(N)].  The decode_table is built
** once at function entry.  The actual state values (0,1,2,...) never appear
** as direct LOADK constants — only random hash values do, and the mapping
** from hash to real state is encoded as table data, not instruction flow.
**
** This hides the state-transition graph: static analysis of the instruction
** stream sees "state_reg = table[random_hash]" instead of "state_reg = 5".
*/
#include <stdlib.h>
#include "obf_util.h"

#ifndef INDDISP_DEBUG
#define INDDISP_DEBUG 0
#endif
#if INDDISP_DEBUG
#include <stdio.h>
#define IDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define IDBG(...)
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

static void indirect_dispatch_function(luac_Proto *p) {
    if (!p->code || p->sizecode < 5) return;
    int n = p->sizecode;

    int state_reg = find_state_reg(p);
    if (state_reg < 0) return; /* not flattened */

    /* ---- collect all LOADK state_reg, K(N) positions and N values ---- */
    int *pos = (int *)malloc(sizeof(int) * n);
    long long *vals = (long long *)malloc(sizeof(long long) * n);
    int nloadk = 0;
    for (int i = 0; i < n; i++) {
        if ((p->code[i] & 0x3F) != LUAC_OP_LOADK) continue;
        int a = (p->code[i] >> 6) & 0xFF;
        int bx = (p->code[i] >> 14) & 0x3FFFF;
        if (a != state_reg || bx >= p->sizek) continue;
        if (!(p->k_tag[bx] == LUA_TNUMINT || p->k_tag[bx] == LUA_TNUMFLT)) continue;
        long long v = (p->k_tag[bx] == LUA_TNUMINT) ? p->k_int[bx] : (long long)p->k_num[bx];
        if (v != (long long)v) continue;
        pos[nloadk] = i;
        vals[nloadk] = v;
        nloadk++;
    }
    if (nloadk < 2) { free(pos); free(vals); return; }

    /* ---- deduplicate N values, assign random hash ---- */
    long long uniq[256];
    long long hash_of[256];
    int nuniq = 0;
    for (int i = 0; i < nloadk; i++) {
        int found = 0;
        for (int j = 0; j < nuniq; j++) {
            if (uniq[j] == vals[i]) { found = 1; break; }
        }
        if (!found) {
            if (nuniq >= 256) break;
            uniq[nuniq] = vals[i];
            /* random 20-bit hash, avoid 0 and small values */
            hash_of[nuniq] = (long long)(obf_rand() % 900000) + 100000 + nuniq;
            nuniq++;
        }
    }

    IDBG("[indirect_dispatch] state_reg=%d nloadk=%d nuniq=%d maxstack=%d\n",
         state_reg, nloadk, nuniq, p->maxstacksize);

    /* ---- registers ---- */
    int table_reg = p->maxstacksize;
    int tmp_reg   = table_reg + 1;
    int tmp2_reg  = table_reg + 2;
    if (tmp2_reg + 1 > 255) { free(pos); free(vals); return; }
    obf_ensure_stack(p, tmp2_reg + 1);

    /* ---- build new code ---- */
    int table_build_size = 1 + nuniq * 3; /* NEWTABLE + per-entry LOADK+LOADK+SETTABLE */
    int max_new = n + nloadk * 1 + table_build_size + 64; /* each LOADK grows by 1 */
    unsigned int *nc = (unsigned int *)malloc(sizeof(unsigned int) * max_new);
    int ni = 0;

    /* build decode_table */
    nc[ni++] = LUAC_ABC(LUAC_OP_NEWTABLE, table_reg, 0, 0);
    for (int u = 0; u < nuniq; u++) {
        int kh = get_int_const_idx(p, hash_of[u]);
        int kv = get_int_const_idx(p, uniq[u]);
        nc[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, kh);
        nc[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp2_reg, kv);
        nc[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, table_reg, tmp_reg, tmp2_reg);
    }

    /* helper: hash of a value */
    #define HASH_OF(v) ({ long long _h = 0; for (int _u=0;_u<nuniq;_u++) if (uniq[_u]==(v)) {_h=hash_of[_u];break;} _h; })

    /* copy original code, replacing LOADK state_reg, K(N) with lookup */
    int *pos_map = (int *)malloc(sizeof(int) * (n + 1));
    int *rev_pos_map = (int *)malloc(sizeof(int) * max_new);
    for (int i = 0; i <= n; i++) pos_map[i] = -1;
    for (int i = 0; i < max_new; i++) rev_pos_map[i] = -1;

    int loadk_idx = 0;
    for (int i = 0; i < n; i++) {
        pos_map[i] = ni;
        if (loadk_idx < nloadk && pos[loadk_idx] == i) {
            long long v = vals[loadk_idx];
            long long h = HASH_OF(v);
            int kh = get_int_const_idx(p, h);
            /* LOADK tmp, K(hash); GETTABLE state_reg, table_reg, tmp */
            nc[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, kh);
            nc[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, state_reg, table_reg, tmp_reg);
            loadk_idx++;
            continue;
        }
        rev_pos_map[ni] = i;
        nc[ni++] = p->code[i];
        /* CALL may clobber high regs (callee's stack frame starts at R(A));
           rebuild decode table so table_reg is valid again */
        if ((p->code[i] & 0x3F) == LUAC_OP_CALL) {
            nc[ni++] = LUAC_ABC(LUAC_OP_NEWTABLE, table_reg, 0, 0);
            for (int u = 0; u < nuniq; u++) {
                int kh = get_int_const_idx(p, hash_of[u]);
                int kv = get_int_const_idx(p, uniq[u]);
                nc[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, kh);
                nc[ni++] = LUAC_ABx(LUAC_OP_LOADK, tmp2_reg, kv);
                nc[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, table_reg, tmp_reg, tmp2_reg);
            }
        }
    }
    pos_map[n] = ni;

    /* ---- fixup all JMP targets: use original position from rev_pos_map ---- */
    for (int i = 0; i < ni; i++) {
        if (rev_pos_map[i] < 0) continue;
        int orig_i = rev_pos_map[i];
        int op = nc[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP ||
            op == LUAC_OP_TFORLOOP) {
            int sbx = (int)(nc[i] >> 14) - 131071;
            int orig_target = orig_i + 1 + sbx;
            if (orig_target >= 0 && orig_target < n && pos_map[orig_target] >= 0) {
                int new_sbx = pos_map[orig_target] - i - 1;
                nc[i] = (nc[i] & 0x3FFF) | (((new_sbx + 131071) & 0x3FFFF) << 14);
            }
        }
    }

    free(p->code);
    p->code = nc;
    p->sizecode = ni;
    /* lineinfo stripped by flatten already; skip to avoid double-free issues */

    free(pos); free(vals); free(pos_map); free(rev_pos_map);
    #undef HASH_OF
}

int indirect_dispatch_process(lua_State *L) {
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
    for (int i = 0; i < list_count; i++) indirect_dispatch_function(list[i]);
    free(list); free(stk);

    lua_pushinteger(L, 1);
    return 1;
}
