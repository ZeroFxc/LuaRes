/*
** destr_encrypt.c - Reverse string encryption (C implementation, v4)
** Recognizes inline pure-opcode decrypt sequences:
**   LOADK key / LOADK "" / per-byte (LOADK+B XOR+GETTABLE+MOVE+CONCAT) / optional MOVE
** Decrypts bytes via XOR of integer constants, restores original instructions.
*/
#include <string.h>
#include "obf_util.h"

static int is_empty_const(luac_Proto *p, int kidx) {
    if (kidx < 0 || kidx >= p->sizek) return 0;
    if (p->k_tag[kidx] != LUA_TSHRSTR && p->k_tag[kidx] != LUA_TLNGSTR) return 0;
    return p->k_str_len[kidx] == 0;
}

static int get_int_const(luac_Proto *p, int kidx) {
    if (kidx < 0 || kidx >= p->sizek) return -1;
    if (p->k_tag[kidx] != LUA_TNUMINT && p->k_tag[kidx] != LUA_TNUMFLT) return -1;
    return (int)(long long)p->k_num[kidx];
}

/* Parse inline decrypt sequence starting at code[start].
** Returns instruction count consumed, or 0. */
static int parse_inline_decrypt(luac_Proto *p, int start,
                                 unsigned char **out_bytes, int *out_len,
                                 int *out_result_reg) {
    unsigned int *code = p->code;
    int n = p->sizecode;
    if (start + 2 > n) return 0;

    /* ins 0: LOADK key_reg, key_kidx */
    unsigned int ins0 = code[start];
    if ((ins0 & 0x3F) != LUAC_OP_LOADK) return 0;
    int key_reg = (ins0 >> 6) & 0xFF;
    int key_kidx = (int)(ins0 >> 14);
    int key = get_int_const(p, key_kidx);
    if (key < 0) return 0;

    /* ins 1: LOADK concat_reg, empty_kidx */
    unsigned int ins1 = code[start + 1];
    if ((ins1 & 0x3F) != LUAC_OP_LOADK) return 0;
    int concat_reg = (ins1 >> 6) & 0xFF;
    int empty_kidx = (int)(ins1 >> 14);
    if (!is_empty_const(p, empty_kidx)) return 0;

    /* parse per-byte pattern */
    int pos = start + 2;
    int cap = 64;
    unsigned char *bytes = luac_alloc(cap);
    int blen = 0;

    while (pos + 4 <= n) {
        unsigned int i0 = code[pos];
        if ((i0 & 0x3F) != LUAC_OP_LOADK) break;
        int tmp_reg = (i0 >> 6) & 0xFF;
        int byte_kidx = (int)(i0 >> 14);
        int eb = get_int_const(p, byte_kidx);
        if (eb < 0) break;

        unsigned int i1 = code[pos + 1];
        if ((i1 & 0x3F) != LUAC_OP_BXOR) break;
        if (((i1 >> 6) & 0xFF) != tmp_reg || ((i1 >> 23) & 0x1FF) != tmp_reg || ((i1 >> 14) & 0x1FF) != key_reg) break;

        unsigned int i2 = code[pos + 2];
        if ((i2 & 0x3F) != LUAC_OP_GETTABLE) break;
        if (((i2 >> 6) & 0xFF) != tmp_reg || ((i2 >> 14) & 0x1FF) != tmp_reg) break;
        int b2c_reg = (i2 >> 23) & 0x1FF;

        unsigned int i3 = code[pos + 3];
        if ((i3 & 0x3F) != LUAC_OP_MOVE) break;
        if (((i3 >> 6) & 0xFF) != concat_reg + 1 || ((i3 >> 23) & 0x1FF) != tmp_reg) break;

        unsigned int i4 = code[pos + 4];
        if ((i4 & 0x3F) != LUAC_OP_CONCAT) break;
        if (((i4 >> 6) & 0xFF) != concat_reg || ((i4 >> 23) & 0x1FF) != concat_reg || ((i4 >> 14) & 0x1FF) != concat_reg + 1) break;

        (void)b2c_reg;
        if (blen >= cap) { cap *= 2; bytes = realloc(bytes, cap); }
        bytes[blen++] = (unsigned char)(eb ^ key);
        pos += 5;
    }

    if (blen == 0) { free(bytes); return 0; }

    int result_reg = concat_reg;
    if (pos < n) {
        unsigned int ins = code[pos];
        if ((ins & 0x3F) == LUAC_OP_MOVE && ((ins >> 23) & 0x1FF) == concat_reg) {
            result_reg = (ins >> 6) & 0xFF;
            pos++;
        }
    }

    *out_bytes = bytes;
    *out_len = blen;
    *out_result_reg = result_reg;
    return pos - start;
}

static int decrypt_function(luac_Proto *p) {
    if (!p->code || !p->k_str) return 0;

    unsigned int *code = p->code;
    int n = p->sizecode;
    int count = 0;
    int i = 0;

    while (i < n) {
        unsigned char *bytes = NULL;
        int blen = 0;
        int result_reg = -1;
        int seq_len = parse_inline_decrypt(p, i, &bytes, &blen, &result_reg);
        if (seq_len == 0) { i++; continue; }

        int pt_kidx = obf_add_k_string(p, (const char *)bytes, (size_t)blen);
        free(bytes);

        int after = i + seq_len;
        int remove_start = i;
        int remove_count = seq_len;
        unsigned int replacement = 0;
        int has_replacement = 0;

        if (after < n) {
            unsigned int nxt = code[after];
            int nop = nxt & 0x3F;
            int na = (nxt >> 6) & 0xFF;
            int nb = (nxt >> 23) & 0x1FF;
            int nc = (nxt >> 14) & 0x1FF;

            if (nop == LUAC_OP_GETTABLE && nc == result_reg) {
                replacement = LUAC_ABC(LUAC_OP_GETTABLE, na, nb, pt_kidx + 256);
                remove_count = seq_len + 1;
                has_replacement = 1;
            } else if (nop == LUAC_OP_SELF && nc == result_reg) {
                replacement = LUAC_ABC(LUAC_OP_SELF, na, nb, pt_kidx + 256);
                remove_count = seq_len + 1;
                has_replacement = 1;
            } else if (nop == LUAC_OP_SETTABLE && nb == result_reg) {
                replacement = LUAC_ABC(LUAC_OP_SETTABLE, na, pt_kidx + 256, nc);
                remove_count = seq_len + 1;
                has_replacement = 1;
            } else if (nop == LUAC_OP_SETTABLE && nc == result_reg) {
                replacement = LUAC_ABC(LUAC_OP_SETTABLE, na, nb, pt_kidx + 256);
                remove_count = seq_len + 1;
                has_replacement = 1;
            }
        }

        if (!has_replacement) {
            replacement = LUAC_ABx(LUAC_OP_LOADK, result_reg, pt_kidx);
            has_replacement = 1;
        }

        code[remove_start] = replacement;
        int move_from = remove_start + remove_count;
        int move_count = n - move_from;
        if (move_count > 0) {
            memmove(code + remove_start + 1, code + move_from, sizeof(unsigned int) * move_count);
        }
        n -= (remove_count - 1);
        obf_adjust_jumps_remove(code, n, remove_start + 1, remove_count - 1);
        count++;
        i = remove_start + 1;
    }

    p->sizecode = n;
    return count;
}

int destr_encrypt_process(lua_State *L) {
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
        count += decrypt_function(list[i]);
    }
    lua_pushinteger(L, count);
    return 1;
}
