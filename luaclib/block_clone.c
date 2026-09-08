/*
** block_clone.c - Basic Block Cloning
** Clone each straight-line basic block with register remapping,
** select original or clone via opaque predicate at block entry.
** CFG node count doubles, path explosion, static analysis must
** process both versions.
*/
#include <stdlib.h>
#include <string.h>
#include "obf_util.h"

#define BLOCK_CLONE_DEBUG 0

/*===========================================================================
** Register mapping helpers
**=========================================================================*/

static inline int map_reg(int reg, int high_base) {
    return high_base + reg;
}

static inline int map_rk(int val, int high_base) {
    return (val < LUAC_BITRK) ? (high_base + val) : val;
}

/*===========================================================================
** Rewrite an instruction's register operands to high registers
**=========================================================================*/

static unsigned int clone_rewrite_ins(unsigned int ins, int high_base) {
    int op = ins & 0x3F;
    int A = (ins >> 6) & 0xFF;
    int C = (ins >> 14) & 0x1FF;
    int B = (ins >> 23) & 0x1FF;
    int Bx = (ins >> 14) & 0x3FFFF;

    switch (op) {
        case LUAC_OP_MOVE: /* 0 */
            return LUAC_ABC(LUAC_OP_MOVE, map_reg(A, high_base), map_reg(B, high_base), 0);
        case LUAC_OP_LOADK: /* 1 */
            return LUAC_ABx(LUAC_OP_LOADK, map_reg(A, high_base), Bx);
        case LUAC_OP_LOADBOOL: /* 3 */
            return LUAC_ABC(LUAC_OP_LOADBOOL, map_reg(A, high_base), B, C);
        case LUAC_OP_LOADNIL: /* 4 */
            return LUAC_ABC(LUAC_OP_LOADNIL, map_reg(A, high_base), map_reg(B, high_base), 0);
        case LUAC_OP_GETUPVAL: /* 5 */
            return LUAC_ABC(LUAC_OP_GETUPVAL, map_reg(A, high_base), B, 0);
        case LUAC_OP_GETTABUP: /* 6 */
            return LUAC_ABC(LUAC_OP_GETTABUP, map_reg(A, high_base), B, map_rk(C, high_base));
        case LUAC_OP_GETTABLE: /* 7 */
            return LUAC_ABC(LUAC_OP_GETTABLE, map_reg(A, high_base), map_reg(B, high_base), map_rk(C, high_base));
        case LUAC_OP_SETTABUP: /* 8 */
            return LUAC_ABC(LUAC_OP_SETTABUP, map_reg(A, high_base), B, map_rk(C, high_base));
        case LUAC_OP_SETUPVAL: /* 9 */
            return LUAC_ABC(LUAC_OP_SETUPVAL, map_reg(A, high_base), B, 0);
        case LUAC_OP_SETTABLE: /* 10 */
            return LUAC_ABC(LUAC_OP_SETTABLE, map_reg(A, high_base), map_rk(B, high_base), map_rk(C, high_base));
        case LUAC_OP_NEWTABLE: /* 12 */
            return LUAC_ABC(LUAC_OP_NEWTABLE, map_reg(A, high_base), B, C);
        case LUAC_OP_ADD: case LUAC_OP_SUB: case LUAC_OP_MUL:
        case LUAC_OP_MOD: case LUAC_OP_POW: case LUAC_OP_DIV:
        case LUAC_OP_IDIV: case LUAC_OP_BAND: case LUAC_OP_BOR:
        case LUAC_OP_BXOR: case LUAC_OP_SHL: case LUAC_OP_SHR:
            return LUAC_ABC(op, map_reg(A, high_base), map_rk(B, high_base), map_rk(C, high_base));
        case LUAC_OP_UNM: case LUAC_OP_BNOT:
        case LUAC_OP_NOT: case LUAC_OP_LEN:
            return LUAC_ABC(op, map_reg(A, high_base), map_rk(B, high_base), 0);
        case LUAC_OP_CONCAT: /* 29 */
            return LUAC_ABC(LUAC_OP_CONCAT, map_reg(A, high_base), map_reg(B, high_base), map_reg(C, high_base));
        case LUAC_OP_SETLIST: /* 43 */
            return LUAC_ABC(LUAC_OP_SETLIST, map_reg(A, high_base), B, C);
        default:
            return ins; /* should not happen for cloneable blocks */
    }
}

/*===========================================================================
** Basic block identification
**=========================================================================*/

typedef struct {
    int start;
    int end; /* inclusive */
} Block;

static int find_blocks(luac_Proto *p, Block **out_blocks) {
    int n = p->sizecode;
    if (n <= 0) { *out_blocks = NULL; return 0; }

    char *is_start = (char *)calloc(n, 1);
    is_start[0] = 1;

    /* Mark jump targets and fall-through positions */
    for (int i = 0; i < n; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            int sbx = ((p->code[i] >> 14) & 0x3FFFF) - 131071;
            int target = i + 1 + sbx;
            if (target >= 0 && target < n) is_start[target] = 1;
        }
        if (op == LUAC_OP_JMP || op == LUAC_OP_RETURN || op == LUAC_OP_TAILCALL ||
            op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            if (i + 1 < n) is_start[i + 1] = 1;
        }
    }

    /* Build block list */
    int cap = n / 2 + 4;
    Block *blocks = (Block *)malloc(sizeof(Block) * cap);
    int count = 0;
    int cur = 0;

    for (int i = 1; i <= n; i++) {
        if (i == n || is_start[i]) {
            blocks[count].start = cur;
            blocks[count].end = i - 1;
            count++;
            cur = i;
        }
    }

    free(is_start);
    *out_blocks = blocks;
    return count;
}

/*===========================================================================
** Check if a block is cloneable (straight-line, no complex ops)
**=========================================================================*/

static int is_cloneable(luac_Proto *p, int start, int end) {
    int len = end - start + 1;
    if (len < 2 || len > 15) return 0;

    for (int i = start; i <= end; i++) {
        int op = p->code[i] & 0x3F;
        /* Block terminators / jump instructions */
        if (op == LUAC_OP_JMP || op == LUAC_OP_RETURN || op == LUAC_OP_TAILCALL) return 0;
        if (op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) return 0;
        /* Conditional ops (always followed by JMP) */
        if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) return 0;
        if (op == LUAC_OP_TEST || op == LUAC_OP_TESTSET) return 0;
        /* Complex / unsupported */
        if (op == LUAC_OP_LOADKX) return 0;   /* needs EXTRAARG */
        if (op == LUAC_OP_CALL) return 0;       /* side effects */
        if (op == LUAC_OP_TFORCALL) return 0;
        if (op == LUAC_OP_CLOSURE) return 0;    /* upvalue setup */
        if (op == LUAC_OP_VARARG) return 0;
        if (op == LUAC_OP_EXTRAARG) return 0;
        if (op == LUAC_OP_SELF) return 0;        /* writes A+1 */
        if (op == LUAC_OP_SETLIST) {
            int C = (p->code[i] >> 14) & 0x1FF;
            if (C == 0) return 0; /* needs EXTRAARG */
        }
        /* Condition ops (EQ/LT/LE/TEST/TESTSET) are followed by JMP,
           so they won't appear in a straight-line block anyway */
    }
    return 1;
}

/*===========================================================================
** Analyze block registers: inputs (read-before-write) and outputs (written)
**=========================================================================*/

static void analyze_block(luac_Proto *p, int start, int end,
                          char *input, char *output, int *max_reg) {
    char written[256];
    memset(written, 0, sizeof(written));
    *max_reg = 0;

    #define MR(r) do { if ((r) < 256) { if (!written[r]) input[r] = 1; if ((r) > *max_reg) *max_reg = (r); } } while(0)
    #define MW(r) do { if ((r) < 256) { written[r] = 1; output[r] = 1; if ((r) > *max_reg) *max_reg = (r); } } while(0)

    for (int i = start; i <= end; i++) {
        int op = p->code[i] & 0x3F;
        int A = (p->code[i] >> 6) & 0xFF;
        int C = (p->code[i] >> 14) & 0x1FF;
        int B = (p->code[i] >> 23) & 0x1FF;

        switch (op) {
            case LUAC_OP_MOVE: MR(B); MW(A); break;
            case LUAC_OP_LOADK: MW(A); break;
            case LUAC_OP_LOADBOOL: MW(A); break;
            case LUAC_OP_LOADNIL: for (int r = A; r <= B; r++) MW(r); break;
            case LUAC_OP_GETUPVAL: MW(A); break;
            case LUAC_OP_GETTABUP: if (C < LUAC_BITRK) MR(C); MW(A); break;
            case LUAC_OP_GETTABLE: MR(B); if (C < LUAC_BITRK) MR(C); MW(A); break;
            case LUAC_OP_SETTABUP: MR(A); if (C < LUAC_BITRK) MR(C); break;
            case LUAC_OP_SETUPVAL: MR(A); break;
            case LUAC_OP_SETTABLE: MR(A); if (B < LUAC_BITRK) MR(B); if (C < LUAC_BITRK) MR(C); break;
            case LUAC_OP_NEWTABLE: MW(A); break;
            case LUAC_OP_ADD: case LUAC_OP_SUB: case LUAC_OP_MUL:
            case LUAC_OP_MOD: case LUAC_OP_POW: case LUAC_OP_DIV:
            case LUAC_OP_IDIV: case LUAC_OP_BAND: case LUAC_OP_BOR:
            case LUAC_OP_BXOR: case LUAC_OP_SHL: case LUAC_OP_SHR:
                if (B < LUAC_BITRK) MR(B); if (C < LUAC_BITRK) MR(C); MW(A); break;
            case LUAC_OP_UNM: case LUAC_OP_BNOT:
            case LUAC_OP_NOT: case LUAC_OP_LEN:
                if (B < LUAC_BITRK) MR(B); MW(A); break;
            case LUAC_OP_CONCAT:
                for (int r = B; r <= C; r++) MR(r); MW(A); break;
            case LUAC_OP_SETLIST:
                MR(A); for (int r = A + 1; r <= A + B; r++) MR(r); break;
        }
    }

    #undef MR
    #undef MW
}

/*===========================================================================
** Main: clone blocks in a proto
**=========================================================================*/

static int clone_blocks_in_proto(luac_Proto *p, int max_clones) {
    if (!p->code || p->sizecode < 4) return 0;

    Block *blocks = NULL;
    int nblocks = find_blocks(p, &blocks);
    if (nblocks == 0) return 0;

    /* Find cloneable blocks */
    int *cidx = (int *)malloc(sizeof(int) * nblocks);
    int ncloneable = 0;
    for (int i = 0; i < nblocks; i++) {
        if (is_cloneable(p, blocks[i].start, blocks[i].end)) {
            cidx[ncloneable++] = i;
        }
    }

    if (ncloneable == 0) { free(cidx); free(blocks); return 0; }

    /* Randomly select up to max_clones blocks */
    int nselect = (max_clones > 0 && max_clones < ncloneable) ? max_clones : ncloneable;
    /* Fisher-Yates shuffle then take first nselect */
    for (int i = ncloneable - 1; i > 0; i--) {
        int j = obf_rand() % (i + 1);
        int tmp = cidx[i]; cidx[i] = cidx[j]; cidx[j] = tmp;
    }

    /* Mark selected blocks */
    char *selected = (char *)calloc(nblocks, 1);
    for (int i = 0; i < nselect; i++) selected[cidx[i]] = 1;

#if BLOCK_CLONE_DEBUG
    fprintf(stderr, "[block_clone] proto sizecode=%d, blocks=%d, cloneable=%d, selected=%d\n",
            p->sizecode, nblocks, ncloneable, nselect);
#endif

    /* Determine high register base and extend stack */
    int high_base = p->maxstacksize;
    int need_extra = 0;
    for (int bi = 0; bi < nblocks; bi++) {
        if (!selected[bi]) continue;
        char input[256] = {0}, output[256] = {0};
        int max_reg = 0;
        analyze_block(p, blocks[bi].start, blocks[bi].end, input, output, &max_reg);
        int extra = max_reg + 2; /* high regs + temp for predicate */
        if (extra > need_extra) need_extra = extra;
    }

    int new_max = high_base + need_extra;
    if (new_max > 250) new_max = 250;
    obf_ensure_stack(p, new_max);
    high_base = p->maxstacksize - need_extra; /* recompute after ensure */

    /* Build new code array */
    int old_n = p->sizecode;
    int est_new = old_n + nselect * 20; /* generous estimate */
    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * est_new);
    int *pos_map = (int *)malloc(sizeof(int) * old_n); /* old_pos -> new_pos */
    int new_n = 0;

    /* Track special JMP positions for fixing */
    typedef struct { int pred_jmp_pos; int orig_jmp_pos; int clone_start; int merge_pos; } CloneInfo;
    CloneInfo *cinfo = (CloneInfo *)malloc(sizeof(CloneInfo) * nselect);
    int cinfo_count = 0;

    int old_i = 0;
    for (int bi = 0; bi < nblocks; bi++) {
        int bstart = blocks[bi].start;
        int bend = blocks[bi].end;
        int blen = bend - bstart + 1;

        /* Copy any instructions before this block (shouldn't happen since blocks cover all) */
        while (old_i < bstart) {
            pos_map[old_i] = new_n;
            new_code[new_n++] = p->code[old_i];
            old_i++;
        }

        if (selected[bi]) {
            /* Analyze registers */
            char input[256] = {0}, output[256] = {0};
            int max_reg = 0;
            analyze_block(p, bstart, bend, input, output, &max_reg);

            int temp_reg = high_base + max_reg + 1;
            if (temp_reg >= p->maxstacksize) temp_reg = p->maxstacksize - 1;

            /* Record position mapping for block start */
            pos_map[bstart] = new_n;

            /* --- Opaque predicate (always true -> original) --- */
            int pred_jmp_new = new_n + 2; /* position of the JMP in predicate */
            new_code[new_n++] = LUAC_ABC(LUAC_OP_LOADBOOL, temp_reg, 1, 0); /* R = true */
            new_code[new_n++] = LUAC_ABC(LUAC_OP_TEST, temp_reg, 0, 0);       /* if true skip JMP */
            new_code[new_n++] = LUAC_AsBx(LUAC_OP_JMP, 0, 0);                  /* -> clone (fixed later) */

            /* --- Original block (unchanged) --- */
            for (int j = bstart; j <= bend; j++) {
                pos_map[j] = new_n;
                new_code[new_n++] = p->code[j];
            }

            /* --- JMP to merge (skip clone) --- */
            int orig_jmp_new = new_n;
            new_code[new_n++] = LUAC_AsBx(LUAC_OP_JMP, 0, 0); /* -> merge (fixed later) */

            /* --- Clone block --- */
            int clone_start_new = new_n;

            /* Copy inputs to high registers */
            for (int r = 0; r < 256; r++) {
                if (input[r]) {
                    new_code[new_n++] = LUAC_ABC(LUAC_OP_MOVE, high_base + r, r, 0);
                }
            }

            /* Remapped instructions */
            for (int j = bstart; j <= bend; j++) {
                new_code[new_n++] = clone_rewrite_ins(p->code[j], high_base);
            }

            /* Copy outputs from high registers */
            for (int r = 0; r < 256; r++) {
                if (output[r]) {
                    new_code[new_n++] = LUAC_ABC(LUAC_OP_MOVE, r, high_base + r, 0);
                }
            }

            /* Merge position (after clone) */
            int merge_new = new_n;

            /* Record clone info for JMP fixing */
            cinfo[cinfo_count].pred_jmp_pos = pred_jmp_new;
            cinfo[cinfo_count].orig_jmp_pos = orig_jmp_new;
            cinfo[cinfo_count].clone_start = clone_start_new;
            cinfo[cinfo_count].merge_pos = merge_new;
            cinfo_count++;

            old_i = bend + 1;
        } else {
            /* Non-cloneable block: copy as-is */
            for (int j = bstart; j <= bend; j++) {
                pos_map[j] = new_n;
                new_code[new_n++] = p->code[j];
            }
            old_i = bend + 1;
        }
    }

    /* Fix special JMPs (predicate -> clone, original -> merge) */
    for (int i = 0; i < cinfo_count; i++) {
        int pj = cinfo[i].pred_jmp_pos;
        int oj = cinfo[i].orig_jmp_pos;
        int cs = cinfo[i].clone_start;
        int mg = cinfo[i].merge_pos;

        /* predicate JMP: from pj+1 to cs */
        int sbx_pred = cs - (pj + 1);
        new_code[pj] = LUAC_AsBx(LUAC_OP_JMP, 0, sbx_pred);

        /* original JMP: from oj+1 to mg */
        int sbx_orig = mg - (oj + 1);
        new_code[oj] = LUAC_AsBx(LUAC_OP_JMP, 0, sbx_orig);
    }

    /* Fix all original JMP/FORLOOP/FORPREP/TFORLOOP targets */
    for (int i = 0; i < new_n; i++) {
        int op = new_code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            /* Check if this is a special JMP we already fixed */
            int is_special = 0;
            for (int j = 0; j < cinfo_count; j++) {
                if (i == cinfo[j].pred_jmp_pos || i == cinfo[j].orig_jmp_pos) {
                    is_special = 1; break;
                }
            }
            if (is_special) continue;

            /* This is an original instruction - find its old position */
            /* We need reverse mapping: new_pos -> old_pos */
            /* Since we built pos_map[old] = new, we can search */
            int old_pos = -1;
            for (int j = 0; j < old_n; j++) {
                if (pos_map[j] == i) { old_pos = j; break; }
            }
            if (old_pos < 0) continue;

            int old_sbx = ((p->code[old_pos] >> 14) & 0x3FFFF) - 131071;
            int old_target = old_pos + 1 + old_sbx;

            if (old_target >= 0 && old_target < old_n) {
                int new_target = pos_map[old_target];
                int new_sbx = new_target - (i + 1);
                new_code[i] = LUAC_AsBx(op, (new_code[i] >> 6) & 0xFF, new_sbx);
            }
        }
    }

    /* Replace proto code */
    free(p->code);
    p->code = new_code;
    p->sizecode = new_n;

    /* Strip lineinfo (modified code) */
    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;

#if BLOCK_CLONE_DEBUG
    fprintf(stderr, "[block_clone] done: old=%d new=%d (+%d), clones=%d\n",
            old_n, new_n, new_n - old_n, cinfo_count);
#endif

    int changes = cinfo_count;

    free(pos_map);
    free(cinfo);
    free(cidx);
    free(selected);
    free(blocks);

    return changes;
}

/*===========================================================================
** Entry point
**=========================================================================*/

int block_clone_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int max_clones = 0; /* 0 = all cloneable blocks */
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) max_clones = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }

    int changes = clone_blocks_in_proto(p, max_clones);

    /* Recursively process sub-protos */
    if (p->p) {
        for (int i = 0; i < p->sizep; i++) {
            changes += clone_blocks_in_proto(p->p[i], max_clones);
        }
    }

    lua_pushinteger(L, changes);
    return 1;
}
