/*
** str_split.c - String split + CONCAT obfuscation (C implementation)
** Splits string constants into shuffled segments, rebuilds via LOADK+CONCAT at runtime.
** Handles: LOADK, GETTABUP, GETTABLE, SETTABUP, SETTABLE, SELF
*/
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "obf_util.h"

#define BITRK 0x100

typedef struct {
    int seg_idx[8];  /* constant pool index for each segment in correct order */
    int n;
} SegInfo;

static int choose_segments(int len) {
    if (len <= 2) return 2;
    if (len <= 5) return 3;
    return 4;
}

/* 找到 >= pos 的最近 UTF-8 字符边界（跳过续字节 0x80-0xBF） */
static int utf8_next_boundary(const char *s, int len, int pos) {
    if (pos <= 0) return 0;
    if (pos >= len) return len;
    while (pos < len && ((unsigned char)s[pos] & 0xC0) == 0x80) pos++;
    return pos;
}

static int is_string_const(luac_Proto *p, int idx) {
    if (idx < 0 || idx >= p->sizek) return 0;
    return (p->k_tag[idx] == LUA_TSHRSTR || p->k_tag[idx] == LUA_TLNGSTR) && p->k_str[idx] != NULL;
}

/* Valid UTF-8 check. On a nested/2nd pass, string constants left by str_encrypt are
   XOR random bytes (almost never valid UTF-8); splitting them by UTF-8 boundaries corrupts
   the ciphertext. Legit source string constants are always valid UTF-8. */
static int is_valid_utf8(const char *pp, int len) {
    const unsigned char *s = (const unsigned char *)pp; int i = 0;
    while (i < len) {
        unsigned char c = s[i];
        if (c < 0x80) { i++; }
        else if (c >= 0xC2 && c <= 0xDF) {
            if (i+1 >= len || (s[i+1] & 0xC0) != 0x80) return 0; i += 2;
        } else if (c >= 0xE0 && c <= 0xEF) {
            if (i+2 >= len || (s[i+1]&0xC0)!=0x80 || (s[i+2]&0xC0)!=0x80) return 0;
            if (c==0xE0 && s[i+1]<0xA0) return 0;
            if (c==0xED && s[i+1]>=0xA0) return 0; i += 3;
        } else if (c >= 0xF0 && c <= 0xF4) {
            if (i+3 >= len || (s[i+1]&0xC0)!=0x80 || (s[i+2]&0xC0)!=0x80 || (s[i+3]&0xC0)!=0x80) return 0;
            if (c==0xF0 && s[i+1]<0x90) return 0;
            if (c==0xF4 && s[i+1]>=0x90) return 0; i += 4;
        } else return 0;
    }
    return 1;
}

static int process_function(luac_Proto *p) {
    if (!p->code || !p->k_str || p->sizek == 0) return 0;
    int orig_code = p->sizecode;
    int orig_k = p->sizek;
    int min_len = 2;

    /* collect unique string indices referenced in code */
    int *str_set = (int *)calloc(orig_k, sizeof(int));
    int ref_count = 0;
    for (int i = 0; i < orig_code; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        if (op == LUAC_OP_LOADK) {
            int bx = (int)(ins >> 14);
            if (is_string_const(p, bx)) { str_set[bx] = 1; ref_count++; }
        } else if (op == LUAC_OP_GETTABUP || op == LUAC_OP_GETTABLE || op == LUAC_OP_SELF) {
            int c = (ins >> 14) & 0x1FF;
            if (c >= BITRK && is_string_const(p, c - BITRK)) { str_set[c - BITRK] = 1; ref_count++; }
        } else if (op == LUAC_OP_SETTABUP || op == LUAC_OP_SETTABLE) {
            int b = (ins >> 23) & 0x1FF;
            int c = (ins >> 14) & 0x1FF;
            if (b >= BITRK && is_string_const(p, b - BITRK)) { str_set[b - BITRK] = 1; ref_count++; }
            if (c >= BITRK && is_string_const(p, c - BITRK)) { str_set[c - BITRK] = 1; ref_count++; }
        }
    }
    if (ref_count == 0) { free(str_set); return 0; }

    SegInfo *seg_map = (SegInfo *)calloc(orig_k, sizeof(SegInfo));

    /* split each string and add segments to constant pool */
    for (int idx = 0; idx < orig_k; idx++) {
        if (!str_set[idx]) continue;
        int len = p->k_str_len[idx];
        if (len < min_len) continue;
        const char *s = p->k_str[idx];

        if (!is_valid_utf8(s, len)) continue; /* ciphertext/raw bytes from a prior pass: do not split */
        int n = choose_segments(len);
        int seg = len / n;
        if (seg < 1) seg = 1;

        /* 预计算每个拆分点的 UTF-8 边界位置 */
        int bounds[8];
        for (int i = 0; i < n - 1; i++) {
            int raw = (i + 1) * seg;
            bounds[i] = utf8_next_boundary(s, len, raw);
        }
        bounds[n - 1] = len;

        /* split into parts (按 UTF-8 边界切分，避免截断多字节字符) */
        char *parts[8];
        int part_lens[8];
        int pos = 0;
        int actual_n = 0;
        for (int i = 0; i < n; i++) {
            int end = bounds[i];
            int this_seg = end - pos;
            if (this_seg < 1) continue;  /* 边界重合，跳过空片段 */
            if (pos + this_seg > len) this_seg = len - pos;
            parts[actual_n] = (char *)malloc(this_seg + 1);
            if (this_seg > 0) memcpy(parts[actual_n], s + pos, this_seg);
            parts[actual_n][this_seg] = '\0';
            part_lens[actual_n] = this_seg;
            pos += this_seg;
            actual_n++;
        }
        n = actual_n;
        if (n < 2) {  /* 无法拆成 >=2 个有效片段，跳过此字符串 */
            for (int i = 0; i < actual_n; i++) free(parts[i]);
            continue;
        }

        /* Fisher-Yates shuffle of add order */
        int perm[8];
        for (int i = 0; i < n; i++) perm[i] = i;
        for (int i = n - 1; i > 0; i--) {
            int j = obf_rand() % (i + 1);
            int t = perm[i]; perm[i] = perm[j]; perm[j] = t;
        }

        /* add segments in shuffled order, record correct-order indices */
        for (int pi = 0; pi < n; pi++) {
            int seg_i = perm[pi];
            int cidx = obf_add_k_string(p, parts[seg_i], part_lens[seg_i]);
            seg_map[idx].seg_idx[seg_i] = cidx;
        }
        seg_map[idx].n = n;

        /* replace original string with junk of same length */
        char *junk = (char *)malloc(len + 1);
        for (int j = 0; j < len; j++) junk[j] = (char)(33 + obf_rand() % 94);
        junk[len] = '\0';
        free(p->k_str[idx]);
        p->k_str[idx] = junk;
        p->k_str_len[idx] = len;

        for (int i = 0; i < n; i++) free(parts[i]);
    }

    /* check if any string was split */
    int has_any = 0;
    for (int i = 0; i < orig_k; i++) {
        if (seg_map[i].n > 0) { has_any = 1; break; }
    }
    if (!has_any) {
        free(seg_map); free(str_set);
        return 0;
    }

    /* calc max reg */
    int max_r = p->maxstacksize - 1;
    for (int i = 0; i < orig_code; i++) {
        int op = p->code[i] & 0x3F;
        int a = (p->code[i] >> 6) & 0xFF;
        if (a > max_r) max_r = a;
        if (op <= 46) {
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (b < 255 && b > max_r) max_r = b;
            if (c < 255 && c > max_r) max_r = c;
        }
    }
    int tmp_base = max_r + 5;
    if (tmp_base + 24 > 250) { free(seg_map); free(str_set); return 0; } /* need 24 contiguous scratch regs strictly above used range */

    /* build new code */
    int max_new = orig_code * 16 + 256;
    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * max_new);
    int ni = 0;
    int *insert_pos = (int *)calloc(orig_code + 1, sizeof(int));
    int *insert_len = (int *)calloc(orig_code + 1, sizeof(int));
    int inserted_so_far = 0;

    for (int i = 0; i < orig_code; i++) {
        insert_pos[i] = inserted_so_far;
        int start_ni = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;
        int b = (ins >> 23) & 0x1FF;
        int c = (ins >> 14) & 0x1FF;
        int handled = 0;

        if (op == LUAC_OP_LOADK) {
            int bx = (int)(ins >> 14);
            if (bx < orig_k && seg_map[bx].n > 0) {
                SegInfo *sg = &seg_map[bx];
                int kr = tmp_base;
                for (int j = 0; j < sg->n; j++)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr + j, sg->seg_idx[j]);
                if (sg->n >= 2)
                    new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr, kr, kr + sg->n - 1);
                new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, a, kr, 0);
                handled = 1;
            }
        } else if (op == LUAC_OP_GETTABUP) {
            if (c >= BITRK && (c - BITRK) < orig_k && seg_map[c - BITRK].n > 0) {
                SegInfo *sg = &seg_map[c - BITRK];
                int kr = tmp_base, tr = tmp_base + sg->n;
                new_code[ni++] = LUAC_ABC(LUAC_OP_GETUPVAL, tr, b, 0);
                for (int j = 0; j < sg->n; j++)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr + j, sg->seg_idx[j]);
                if (sg->n >= 2)
                    new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr, kr, kr + sg->n - 1);
                new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, a, tr, kr);
                handled = 1;
            }
        } else if (op == LUAC_OP_GETTABLE) {
            if (c >= BITRK && (c - BITRK) < orig_k && seg_map[c - BITRK].n > 0) {
                SegInfo *sg = &seg_map[c - BITRK];
                int kr = tmp_base;
                for (int j = 0; j < sg->n; j++)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr + j, sg->seg_idx[j]);
                if (sg->n >= 2)
                    new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr, kr, kr + sg->n - 1);
                new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, a, b, kr);
                handled = 1;
            }
        } else if (op == LUAC_OP_SETTABUP) {
            int b_sp = (b >= BITRK && (b - BITRK) < orig_k && seg_map[b - BITRK].n > 0);
            int c_sp = (c >= BITRK && (c - BITRK) < orig_k && seg_map[c - BITRK].n > 0);
            if (b_sp || c_sp) {
                int vr = tmp_base, kr = tmp_base + 8, tr = tmp_base + 16;
                new_code[ni++] = LUAC_ABC(LUAC_OP_GETUPVAL, tr, a, 0);
                /* rebuild value */
                if (c_sp) {
                    SegInfo *sgc = &seg_map[c - BITRK];
                    for (int j = 0; j < sgc->n; j++)
                        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, vr + j, sgc->seg_idx[j]);
                    if (sgc->n >= 2)
                        new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, vr, vr, vr + sgc->n - 1);
                } else if (c >= BITRK)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, vr, c - BITRK);
                else
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, vr, c, 0);
                /* rebuild key */
                if (b_sp) {
                    SegInfo *sg = &seg_map[b - BITRK];
                    for (int j = 0; j < sg->n; j++)
                        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr + j, sg->seg_idx[j]);
                    if (sg->n >= 2)
                        new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr, kr, kr + sg->n - 1);
                } else if (b >= BITRK)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr, b - BITRK);
                else
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, kr, b, 0);
                new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, tr, kr, vr);
                handled = 1;
            }
        } else if (op == LUAC_OP_SETTABLE) {
            int b_sp = (b >= BITRK && (b - BITRK) < orig_k && seg_map[b - BITRK].n > 0);
            int c_sp = (c >= BITRK && (c - BITRK) < orig_k && seg_map[c - BITRK].n > 0);
            if (b_sp || c_sp) {
                int vr = tmp_base, kr = tmp_base + 8;
                /* rebuild value */
                if (c_sp) {
                    SegInfo *sgc = &seg_map[c - BITRK];
                    for (int j = 0; j < sgc->n; j++)
                        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, vr + j, sgc->seg_idx[j]);
                    if (sgc->n >= 2)
                        new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, vr, vr, vr + sgc->n - 1);
                } else if (c >= BITRK)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, vr, c - BITRK);
                else
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, vr, c, 0);
                /* rebuild key */
                if (b_sp) {
                    SegInfo *sg = &seg_map[b - BITRK];
                    for (int j = 0; j < sg->n; j++)
                        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr + j, sg->seg_idx[j]);
                    if (sg->n >= 2)
                        new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr, kr, kr + sg->n - 1);
                } else if (b >= BITRK)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr, b - BITRK);
                else
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, kr, b, 0);
                new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, a, kr, vr);
                handled = 1;
            }
        } else if (op == LUAC_OP_SELF) {
            if (c >= BITRK && (c - BITRK) < orig_k && seg_map[c - BITRK].n > 0) {
                SegInfo *sg = &seg_map[c - BITRK];
                int kr = tmp_base;
                new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, a + 1, b, 0);
                for (int j = 0; j < sg->n; j++)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr + j, sg->seg_idx[j]);
                if (sg->n >= 2)
                    new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr, kr, kr + sg->n - 1);
                new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, a, b, kr);
                handled = 1;
            }
        } else if (op == LUAC_OP_EQ) {
            /* EQ A B C: B=寄存器, C=RK。若 C 是已拆分的字符串，先拼接到临时寄存器 */
            if (c >= BITRK && (c - BITRK) < orig_k && seg_map[c - BITRK].n > 0) {
                SegInfo *sg = &seg_map[c - BITRK];
                int kr = tmp_base;
                for (int j = 0; j < sg->n; j++)
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr + j, sg->seg_idx[j]);
                if (sg->n >= 2)
                    new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr, kr, kr + sg->n - 1);
                new_code[ni++] = LUAC_ABC(LUAC_OP_EQ, a, b, kr);
                handled = 1;
            }
        } else if (op == LUAC_OP_LT || op == LUAC_OP_LE) {
            /* LT/LE A B C: B 和 C 都是 RK */
            int b_sp = (b >= BITRK && (b - BITRK) < orig_k && seg_map[b - BITRK].n > 0);
            int c_sp = (c >= BITRK && (c - BITRK) < orig_k && seg_map[c - BITRK].n > 0);
            if (b_sp || c_sp) {
                int kr1 = tmp_base, kr2 = tmp_base + 8;
                int nb = b, nc = c;
                if (b_sp) {
                    SegInfo *sg = &seg_map[b - BITRK];
                    for (int j = 0; j < sg->n; j++)
                        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr1 + j, sg->seg_idx[j]);
                    if (sg->n >= 2)
                        new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr1, kr1, kr1 + sg->n - 1);
                    nb = kr1;
                }
                if (c_sp) {
                    SegInfo *sg = &seg_map[c - BITRK];
                    for (int j = 0; j < sg->n; j++)
                        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, kr2 + j, sg->seg_idx[j]);
                    if (sg->n >= 2)
                        new_code[ni++] = LUAC_ABC(LUAC_OP_CONCAT, kr2, kr2, kr2 + sg->n - 1);
                    nc = kr2;
                }
                new_code[ni++] = LUAC_ABC(op, a, nb, nc);
                handled = 1;
            }
        }

        if (!handled) new_code[ni++] = ins;
        insert_len[i] = (ni - start_ni) - 1;
        inserted_so_far += insert_len[i];
    }

    /* adjust jumps - single pass correct algorithm */
    int total_inserted = inserted_so_far;
    for (int i = 0; i < ni; i++) {
        int op = new_code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_TFORLOOP) {
            int a = (new_code[i] >> 6) & 0xFF;
            int sbx = (int)(new_code[i] >> 14) - 131071;
            /* find original index of this jump instruction */
            int orig_i = -1;
            for (int k = 0; k < orig_code; k++) {
                if (k + insert_pos[k] == i) { orig_i = k; break; }
            }
            if (orig_i < 0) continue;
            int orig_target = orig_i + sbx + 1;
            int new_target;
            if (orig_target >= orig_code) {
                new_target = orig_code + total_inserted;
            } else if (orig_target < 0) {
                continue;
            } else {
                new_target = orig_target + insert_pos[orig_target];
            }
            int new_sbx = new_target - i - 1;
            new_code[i] = ((unsigned int)op) | ((unsigned int)a << 6) |
                          ((unsigned int)(new_sbx + 131071) << 14);
        }
    }

    free(p->code);
    p->code = new_code;
    p->sizecode = ni;

    /* lineinfo */
    if (p->lineinfo && p->sizelineinfo > 0) {
        int *new_li = (int *)calloc(ni, sizeof(int));
        for (int i = 0; i < orig_code && i < p->sizelineinfo; i++) {
            int pos = i + insert_pos[i];
            if (pos >= 0 && pos < ni) new_li[pos] = p->lineinfo[i];
        }
        free(p->lineinfo);
        p->lineinfo = new_li;
        p->sizelineinfo = ni;
    }

    int needed = tmp_base + 24;
    if (needed > 250) needed = 250;
    obf_ensure_stack(p, needed);

    free(seg_map); free(str_set); free(insert_pos); free(insert_len);
    return ref_count;
}

int str_split_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
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

    int count = 0;
    for (int i = 0; i < list_count; i++) count += process_function(list[i]);
    free(list);
    free(stk);
    lua_pushinteger(L, count);
    return 1;
}
