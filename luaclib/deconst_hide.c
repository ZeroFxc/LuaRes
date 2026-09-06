/*
** deconst_hide.c - Constant pool hiding reverse (C implementation)
** Detects substring sequences and restores original string constants.
*/
#include <string.h>
#include "obf_util.h"

static int is_sub_proto(luac_Proto *p) {
    if (!p->k_str || !p->code) return 0;
    if (p->numparams != 3) return 0;
    int has_sub = 0;
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TSHRSTR || p->k_tag[i] == LUA_TLNGSTR) && p->k_str[i]
            && strcmp(p->k_str[i], "sub") == 0) has_sub = 1;
    }
    if (!has_sub) return 0;
    int has_self = 0, has_call = 0;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_SELF) has_self = 1;
        if (op == LUAC_OP_CALL || op == LUAC_OP_TAILCALL) has_call = 1;
    }
    return has_self && has_call;
}

static int find_sub_proto(luac_Proto *p) {
    if (!p->p) return -1;
    for (int i = 0; i < p->sizep; i++) {
        if (is_sub_proto(p->p[i])) return i;
    }
    return -1;
}

static int ensure_string_const(luac_Proto *p, const char *s, size_t len) {
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TSHRSTR || p->k_tag[i] == LUA_TLNGSTR) && p->k_str[i]
            && (size_t)p->k_str_len[i] == len && memcmp(p->k_str[i], s, len) == 0)
            return i;
    }
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TNIL) {
            p->k_str[i] = luac_strndup(s, len);
            p->k_str_len[i] = (int)len;
            p->k_tag[i] = (len <= 40) ? LUA_TSHRSTR : LUA_TLNGSTR;
            return i;
        }
    }
    return obf_add_k_string(p, s, len);
}

/* returns 1 if instruction at i is a sub sequence, fills *consumed (original instructions consumed) */
static int try_match_seq(luac_Proto *p, int i, int sub_idx, int *str_kidx_out, int *consumed_out) {
    if (i + 4 >= p->sizecode) return 0;
    if ((p->code[i] & 0x3F) != LUAC_OP_LOADK) return 0;
    if ((p->code[i+1] & 0x3F) != LUAC_OP_CLOSURE) return 0;
    if ((int)(p->code[i+1] >> 14) != sub_idx) return 0;
    if ((p->code[i+2] & 0x3F) != LUAC_OP_LOADK) return 0;
    if ((p->code[i+3] & 0x3F) != LUAC_OP_LOADK) return 0;
    if ((p->code[i+4] & 0x3F) != LUAC_OP_CALL) return 0;

    int call_a = (p->code[i+4] >> 6) & 0xFF;
    int call_b = (p->code[i+4] >> 23) & 0x1FF;
    int call_c = (p->code[i+4] >> 14) & 0x1FF;
    int closure_a = (p->code[i+1] >> 6) & 0xFF;
    if (call_a != closure_a || call_b != 4 || call_c != 2) return 0;

    int blob_kidx = (int)(p->code[i] >> 14);
    int off_kidx = (int)(p->code[i+2] >> 14);
    int endp_kidx = (int)(p->code[i+3] >> 14);
    if (blob_kidx >= p->sizek || off_kidx >= p->sizek || endp_kidx >= p->sizek) return 0;
    if ((p->k_tag[blob_kidx] != LUA_TSHRSTR && p->k_tag[blob_kidx] != LUA_TLNGSTR)) return 0;
    if (p->k_tag[off_kidx] != LUA_TNUMFLT || p->k_tag[endp_kidx] != LUA_TNUMFLT) return 0;
    if (!p->k_str[blob_kidx]) return 0;

    const char *blob = p->k_str[blob_kidx];
    int blob_len = p->k_str_len[blob_kidx];
    int offset = (int)p->k_num[off_kidx];
    int endpos = (int)p->k_num[endp_kidx];
    if (offset < 1) offset = 1;
    if (endpos > blob_len) endpos = blob_len;
    int orig_len = endpos - offset + 1;
    if (orig_len < 0) orig_len = 0;

    *str_kidx_out = ensure_string_const(p, blob + offset - 1, (size_t)orig_len);
    *consumed_out = 5; /* base sequence consumes 5 */
    return 1;
}

static int clean_function(lua_State *L, luac_Proto *p) {
    int sub_idx = find_sub_proto(p);
    if (sub_idx < 0) return 0;

    /* Pass 1: build new code and track original->new position mapping */
    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * p->sizecode);
    int *orig_to_new = luac_alloc(sizeof(int) * (p->sizecode + 1));
    memset(orig_to_new, 0xFF, sizeof(int) * (p->sizecode + 1));  /* -1 */
    int ni = 0;
    int count = 0;
    int i = 0;

    while (i < p->sizecode) {
        orig_to_new[i] = ni;

        int str_kidx = 0, consumed = 0;
        if (try_match_seq(p, i, sub_idx, &str_kidx, &consumed)) {
            int sub_reg = (p->code[i+1] >> 6) & 0xFF;
            int next_i = i + consumed;
            int next_op = (next_i < p->sizecode) ? (p->code[next_i] & 0x3F) : -1;
            int handled = 0;

            if (next_op == LUAC_OP_MOVE) {
                int mv_a = (p->code[next_i] >> 6) & 0xFF;
                int mv_b = (p->code[next_i] >> 23) & 0x1FF;
                if (mv_b == sub_reg) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, mv_a, str_kidx);
                    i = next_i + 1; count++; handled = 1;
                }
            } else if (next_op == LUAC_OP_GETTABLE) {
                int ga = (p->code[next_i] >> 6) & 0xFF;
                int gb = (p->code[next_i] >> 23) & 0x1FF;
                int gc = (p->code[next_i] >> 14) & 0x1FF;
                if (gc == sub_reg) {
                    if (i > 0 && (p->code[i-1] & 0x3F) == LUAC_OP_GETUPVAL) {
                        int gu_a = (p->code[i-1] >> 6) & 0xFF;
                        int gu_b = (p->code[i-1] >> 23) & 0x1FF;
                        if (gu_a == gb && ni > 0) {
                            ni--; /* remove GETUPVAL */
                            new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABUP, ga, gu_b, str_kidx + 256);
                            i = next_i + 1; count++; handled = 1;
                        }
                    }
                    if (!handled) {
                        new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, ga, gb, str_kidx + 256);
                        i = next_i + 1; count++; handled = 1;
                    }
                }
            } else if (next_op == LUAC_OP_SETTABLE) {
                int sa = (p->code[next_i] >> 6) & 0xFF;
                int sb = (p->code[next_i] >> 23) & 0x1FF;
                int sc = (p->code[next_i] >> 14) & 0x1FF;
                if (sb == sub_reg) {
                    /* plain SETTABLE: key is decrypted string */
                    new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, sa, str_kidx + 256, sc);
                    i = next_i + 1; count++; handled = 1;
                } else if (sc == sub_reg) {
                    /* value is decrypted string: check preceding GETUPVAL for SETTABUP */
                    if (i > 0 && (p->code[i-1] & 0x3F) == LUAC_OP_GETUPVAL) {
                        int gu_a = (p->code[i-1] >> 6) & 0xFF;
                        int gu_b = (p->code[i-1] >> 23) & 0x1FF;
                        if (gu_a == sa && ni > 0) {
                            ni--;
                            new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABUP, gu_b, sb, str_kidx + 256);
                            i = next_i + 1; count++; handled = 1;
                        }
                    }
                    if (!handled) {
                        new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, sa, sb, str_kidx + 256);
                        i = next_i + 1; count++; handled = 1;
                    }
                }
            } else if (next_op == LUAC_OP_SELF) {
                int sa = (p->code[next_i] >> 6) & 0xFF;
                int sb = (p->code[next_i] >> 23) & 0x1FF;
                int sc = (p->code[next_i] >> 14) & 0x1FF;
                if (sc == sub_reg) {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_SELF, sa, sb, str_kidx + 256);
                    i = next_i + 1; count++; handled = 1;
                }
            }

            if (handled) continue;
        }

        new_code[ni++] = p->code[i];
        i++;
    }
    orig_to_new[p->sizecode] = ni;

    /* fill gaps for positions consumed by sequences */
    for (int k = 1; k <= p->sizecode; k++) {
        if (orig_to_new[k] == -1) orig_to_new[k] = orig_to_new[k-1];
    }

    /* Pass 2: adjust jumps using orig_to_new mapping */
    for (int j = 0; j < ni; j++) {
        int op = new_code[j] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            /* find original index of this instruction */
            /* we need reverse mapping; rebuild from orig_to_new */
            int orig_j = -1;
            for (int k = 0; k <= p->sizecode; k++) {
                if (orig_to_new[k] == j) { orig_j = k; break; }
            }
            if (orig_j < 0) continue;
            int sbx = (int)(new_code[j] >> 14) - 131071;
            int orig_target = orig_j + sbx + 1;
            if (orig_target < 0) orig_target = 0;
            if (orig_target > p->sizecode) orig_target = p->sizecode;
            int new_target = orig_to_new[orig_target];
            int new_sbx = new_target - j - 1;
            int a = (new_code[j] >> 6) & 0xFF;
            new_code[j] = LUAC_AsBx(op, a, new_sbx);
        }
    }

    /* Adjust CLOSURE indices for removed sub-proto */
    for (int j = 0; j < ni; j++) {
        if ((new_code[j] & 0x3F) == LUAC_OP_CLOSURE) {
            int bx = (int)(new_code[j] >> 14);
            if (bx > sub_idx) {
                int a = (new_code[j] >> 6) & 0xFF;
                new_code[j] = LUAC_ABx(LUAC_OP_CLOSURE, a, bx - 1);
            }
        }
    }

    /* Remove sub-proto */
    if (p->p && sub_idx < p->sizep) {
        for (int j = sub_idx; j < p->sizep - 1; j++)
            p->p[j] = p->p[j+1];
        p->sizep--;
    }

    free(p->code);
    p->code = new_code;
    p->sizecode = ni;
    free(orig_to_new);
    return count;
}

int deconst_hide_process(lua_State *L) {
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
        if (cur->p) {
            for (int j = cur->sizep - 1; j >= 0; j--)
                stack[sp++] = cur->p[j];
        }
    }

    int count = 0;
    for (int i = 0; i < list_count; i++) {
        count += clean_function(L, list[i]);
    }
    lua_pushinteger(L, count);
    return 1;
}
