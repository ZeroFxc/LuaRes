/*
** const_shuffle.c - Shuffle constant pool and fix all instruction references
** Only non-nil constants are shuffled; nil holes stay in place.
*/
#include <time.h>
#include <stdlib.h>
#include "obf_util.h"

static int is_nil_const(luac_Proto *p, int idx) {
    return p->k_tag[idx] == LUA_TNIL || p->k_tag[idx] == LUA_TNONE;
}

static void shuffle_function(luac_Proto *p) {
    if (!p->k_tag || p->sizek <= 1) {
        if (p->p) for (int i = 0; i < p->sizep; i++) shuffle_function(p->p[i]);
        return;
    }

    int n = p->sizek;

    /* collect non-nil constant indices */
    int *non_nil = (int *)malloc(sizeof(int) * n);
    int non_nil_count = 0;
    for (int i = 0; i < n; i++) {
        if (!is_nil_const(p, i)) non_nil[non_nil_count++] = i;
    }

    if (non_nil_count < 2) {
        free(non_nil);
        if (p->p) for (int i = 0; i < p->sizep; i++) shuffle_function(p->p[i]);
        return;
    }

    /* save original non-nil order before shuffling */
    int *orig_non_nil = (int *)malloc(sizeof(int) * non_nil_count);
    memcpy(orig_non_nil, non_nil, sizeof(int) * non_nil_count);

    /* Fisher-Yates shuffle on non-nil indices */
    for (int i = non_nil_count - 1; i > 0; i--) {
        int j = obf_rand() % (i + 1);
        int tmp = non_nil[i]; non_nil[i] = non_nil[j]; non_nil[j] = tmp;
    }

    /* remap[old_idx] = new_idx for all indices (nil holes map to self) */
    int *remap = (int *)malloc(sizeof(int) * n);
    for (int i = 0; i < n; i++) remap[i] = i;
    for (int i = 0; i < non_nil_count; i++) {
        remap[orig_non_nil[i]] = non_nil[i];
    }

    /* inverse remap: for each new position, which old position goes there */
    int *remap_inv = (int *)malloc(sizeof(int) * n);
    for (int i = 0; i < n; i++) remap_inv[remap[i]] = i;

    /* save old arrays */
    int *old_tag = (int *)malloc(sizeof(int) * n);
    char **old_str = (char **)malloc(sizeof(char *) * n);
    int *old_str_len = (int *)malloc(sizeof(int) * n);
    double *old_num = (double *)malloc(sizeof(double) * n);
    int64_t *old_int = (int64_t *)malloc(sizeof(int64_t) * n);
    int *old_bool = (int *)malloc(sizeof(int) * n);
    for (int i = 0; i < n; i++) {
        old_tag[i] = p->k_tag[i];
        old_str[i] = p->k_str[i];
        old_str_len[i] = p->k_str_len[i];
        old_num[i] = p->k_num[i];
        old_int[i] = p->k_int[i];
        old_bool[i] = p->k_bool[i];
    }

    /* rebuild in new order */
    for (int i = 0; i < n; i++) {
        int old_i = remap_inv[i];
        p->k_tag[i] = old_tag[old_i];
        p->k_str[i] = old_str[old_i];
        p->k_str_len[i] = old_str_len[old_i];
        p->k_num[i] = old_num[old_i];
        p->k_int[i] = old_int[old_i];
        p->k_bool[i] = old_bool[old_i];
    }

    free(old_tag); free(old_str); free(old_str_len); free(old_num); free(old_int); free(old_bool);
    free(remap_inv); free(orig_non_nil); free(non_nil);

    /* fix instruction references */
    for (int i = 0; i < p->sizecode; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        if (op == LUAC_OP_LOADK || op == LUAC_OP_LOADKX) {
            int old_bx = (int)(ins >> 14);
            if (old_bx >= 0 && old_bx < n) {
                int a = (ins >> 6) & 0xFF;
                p->code[i] = LUAC_ABx(op, a, remap[old_bx]);
            }
        } else if (op == LUAC_OP_EXTRAARG) {
            int old_ax = (int)(ins >> 6);
            if (old_ax >= 0 && old_ax < n) {
                p->code[i] = LUAC_Ax(op, remap[old_ax]);
            }
        } else if (op != LUAC_OP_CLOSURE && op != LUAC_OP_JMP &&
                   op != LUAC_OP_FORLOOP && op != LUAC_OP_FORPREP &&
                   op != LUAC_OP_TFORLOOP) {
            int a = (ins >> 6) & 0xFF;
            int b = (ins >> 23) & 0x1FF;
            int c = (ins >> 14) & 0x1FF;
            int changed = 0;
            if (b >= LUAC_BITRK) {
                int bi = b - LUAC_BITRK;
                if (bi >= 0 && bi < n) { b = remap[bi] + LUAC_BITRK; changed = 1; }
            }
            if (c >= LUAC_BITRK) {
                int ci = c - LUAC_BITRK;
                if (ci >= 0 && ci < n) { c = remap[ci] + LUAC_BITRK; changed = 1; }
            }
            if (changed) p->code[i] = LUAC_ABC(op, a, b, c);
        }
    }

    free(remap);
    if (p->p) for (int i = 0; i < p->sizep; i++) shuffle_function(p->p[i]);
}

int const_shuffle_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));
    shuffle_function(p);
    lua_pushinteger(L, 1);
    return 1;
}
