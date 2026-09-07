/*
** str_encrypt.c - String constant encryption (C implementation, v5 self-contained pure-opcode)
** Encrypts string constants as XORed byte integer arrays.
** Each decrypt site rebuilds its own byte->char lookup table inline (NEWTABLE+SETTABLE),
** then decrypts with pure opcodes (LOADK/BXOR/GETTABLE/MOVE/CONCAT).
** Table is rebuilt per-site because CALL frames can clobber any register >= base.
** No global state, no Lua function calls, no external dependencies.
** Handles: LOADK, GETTABUP, GETTABLE, SELF, SETTABUP, SETTABLE, EQ, LT, LE
*/
#include <time.h>
#include <string.h>
#include "obf_util.h"

typedef struct {
    int key_kidx;
    int *byte_kidx;
    int nbytes;
} EncInfo;

static int is_enc_rk(int rk, int *str_idx, int str_count) {
    if (rk < 256) return 0;
    int idx = rk - 256;
    for (int i = 0; i < str_count; i++)
        if (str_idx[i] == idx) return 1;
    return 0;
}

/* Emit inline table build + decryption into result_reg.
** Table is rebuilt here so it cannot be clobbered by preceding CALL frames. */
static void emit_inline_decrypt(unsigned int *code, int *ni,
                                 int empty_kidx, EncInfo *ei,
                                 int result_reg, int b2c_reg, int key_reg,
                                 int tmp_reg, int concat_reg,
                                 int *unique_bytes, int unique_count,
                                 int *byte_key_idx, int *byte_char_idx) {
    /* build byte->char lookup table */
    code[(*ni)++] = LUAC_ABC(LUAC_OP_NEWTABLE, b2c_reg, 0, unique_count);
    for (int u = 0; u < unique_count; u++) {
        int b = unique_bytes[u];
        code[(*ni)++] = LUAC_ABC(LUAC_OP_SETTABLE, b2c_reg,
                                  byte_key_idx[b] + 256, byte_char_idx[b] + 256);
    }
    /* decrypt */
    code[(*ni)++] = LUAC_ABx(LUAC_OP_LOADK, key_reg, ei->key_kidx);
    code[(*ni)++] = LUAC_ABx(LUAC_OP_LOADK, concat_reg, empty_kidx);
    for (int i = 0; i < ei->nbytes; i++) {
        code[(*ni)++] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, ei->byte_kidx[i]);
        code[(*ni)++] = LUAC_ABC(LUAC_OP_BXOR, tmp_reg, tmp_reg, key_reg);
        code[(*ni)++] = LUAC_ABC(LUAC_OP_GETTABLE, tmp_reg, b2c_reg, tmp_reg);
        code[(*ni)++] = LUAC_ABC(LUAC_OP_MOVE, concat_reg + 1, tmp_reg, 0);
        code[(*ni)++] = LUAC_ABC(LUAC_OP_CONCAT, concat_reg, concat_reg, concat_reg + 1);
    }
    if (result_reg != concat_reg) {
        code[(*ni)++] = LUAC_ABC(LUAC_OP_MOVE, result_reg, concat_reg, 0);
    }
}

#define DECRYPT(reg) emit_inline_decrypt(new_code, &ni, empty_kidx, ei_arg, \
    (reg), b2c_reg, key_reg, tmp_reg, concat_reg, \
    unique_bytes, unique_count, byte_key_idx, byte_char_idx)

static int encrypt_function(lua_State *L, luac_Proto *p) {
    if (!p->code || !p->k_str) return 0;
    int _dbg_sc = 0;
    for (int _i = 0; _i < p->sizek; _i++) if ((p->k_tag[_i] == 4 || p->k_tag[_i] == 20) && p->k_str[_i]) _dbg_sc++;

    for (int _ci = 0; _ci < p->sizek; _ci++) {
        if (p->k_tag[_ci] == 4 || p->k_tag[_ci] == 20) {
                }
    }

    int *str_idx = luac_alloc(sizeof(int) * p->sizek);
    int str_count = 0;
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TSHRSTR || p->k_tag[i] == LUA_TLNGSTR) && p->k_str[i]
            && p->k_str_len[i] > 0)
            str_idx[str_count++] = i;
    }
    if (str_count == 0) { free(str_idx); return 0; }

    int empty_kidx = obf_add_k_string(p, "", 0);

    EncInfo *enc = luac_alloc(sizeof(EncInfo) * p->sizek);
    memset(enc, 0, sizeof(EncInfo) * p->sizek);
    int seen[256];
    memset(seen, 0, sizeof(seen));
    int unique_bytes[256];
    int unique_count = 0;
    /* compute actual required instruction count BEFORE encryption (k_str_len still valid).
       each decrypt site: 1 NEWTABLE + unique_count SETTABLE + 2 LOADK + 5*nbytes + 1 MOVE.
       Multiple instructions can reference the same string, so multiply by site count. */
    int max_bytes = 0;
    for (int i = 0; i < str_count; i++) {
        int l = p->k_str_len[str_idx[i]];
        if (l > max_bytes) max_bytes = l;
    }
    int site_count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        int b = (p->code[i] >> 23) & 0x1FF;
        int c = (p->code[i] >> 14) & 0x1FF;
        if (op == LUAC_OP_LOADK) {
            int bx = (int)(p->code[i] >> 14);
            for (int j = 0; j < str_count; j++) if (str_idx[j] == bx) { site_count++; break; }
        } else if ((op == LUAC_OP_GETTABUP || op == LUAC_OP_GETTABLE || op == LUAC_OP_SELF) && c >= 256) {
            for (int j = 0; j < str_count; j++) if (str_idx[j] == c - 256) { site_count++; break; }
        } else if (op == LUAC_OP_SETTABUP || op == LUAC_OP_SETTABLE) {
            int hit = 0;
            if (b >= 256) for (int j = 0; j < str_count; j++) if (str_idx[j] == b - 256) { hit = 1; break; }
            if (!hit && c >= 256) for (int j = 0; j < str_count; j++) if (str_idx[j] == c - 256) { hit = 1; break; }
            if (hit) site_count++;
        } else if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) {
            int hit = 0;
            if (b >= 256) for (int j = 0; j < str_count; j++) if (str_idx[j] == b - 256) { hit = 1; break; }
            if (!hit && c >= 256) for (int j = 0; j < str_count; j++) if (str_idx[j] == c - 256) { hit = 1; break; }
            if (hit) site_count++;
        }
    }
    int per_site = 5 * max_bytes + 300;
    int max_new = p->sizecode + site_count * per_site + 1024;

    unsigned int seed = (unsigned int)time(NULL) ^ (unsigned int)(size_t)p;

    for (int i = 0; i < str_count; i++) {
        int idx = str_idx[i];
        int len = p->k_str_len[idx];
        const char *s = p->k_str[idx];
        seed = seed * 1103515245 + 12345;
        int key = (int)(seed & 0xFF);
        if (key == 0) key = 1;
        enc[idx].key_kidx = obf_add_k_integer(p, (long long)key);
        enc[idx].nbytes = len;
        enc[idx].byte_kidx = luac_alloc(sizeof(int) * len);
        for (int j = 0; j < len; j++) {
            unsigned char plain = (unsigned char)s[j];
            int eb = plain ^ key;
            enc[idx].byte_kidx[j] = obf_add_k_integer(p, (long long)eb);
            if (!seen[plain]) { seen[plain] = 1; unique_bytes[unique_count++] = plain; }
        }
        free(p->k_str[idx]);
        p->k_str[idx] = NULL;
        p->k_str_len[idx] = 0;
        p->k_tag[idx] = LUA_TNIL;
    }

    int byte_key_idx[256], byte_char_idx[256];
    for (int i = 0; i < unique_count; i++) {
        int b = unique_bytes[i];
        byte_key_idx[b] = obf_add_k_integer(p, (long long)b);
        char ch = (char)b;
        byte_char_idx[b] = obf_add_k_string(p, &ch, 1);
    }

    int base = p->maxstacksize;
    int b2c_reg = base;
    int key_reg = base + 1;
    int tmp_reg = base + 2;
    int concat_reg = base + 3;
    int res1_reg = base + 5;
    int res2_reg = base + 6;
    int table_reg = base + 7;
    obf_ensure_stack(p, base + 8);

    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * max_new);
    int ni = 0;

    int *insert_pos = luac_alloc(sizeof(int) * (p->sizecode + 1));
    int *insert_len = luac_alloc(sizeof(int) * (p->sizecode + 1));
    memset(insert_pos, 0, sizeof(int) * (p->sizecode + 1));
    memset(insert_len, 0, sizeof(int) * (p->sizecode + 1));
    int inserted_so_far = 0;
    int count = 0;
    EncInfo *ei_arg;

    for (int i = 0; i < p->sizecode; i++) {
        insert_pos[i] = inserted_so_far;
        int start_ni = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;
        int b = (ins >> 23) & 0x1FF;
        int c = (ins >> 14) & 0x1FF;

        if (op == LUAC_OP_LOADK) {
            int bx = (int)(ins >> 14);
            int found = -1;
            for (int j = 0; j < str_count; j++)
                if (bx == str_idx[j]) { found = j; break; }
            if (found >= 0) {
                ei_arg = &enc[bx];
                DECRYPT(a);
                count++;
            } else {
                new_code[ni++] = ins;
            }
        } else if (op == LUAC_OP_GETTABUP && is_enc_rk(c, str_idx, str_count)) {
            int cidx = c - 256;
            new_code[ni++] = LUAC_ABC(LUAC_OP_GETUPVAL, table_reg, b, 0);
            ei_arg = &enc[cidx];
            DECRYPT(res1_reg);
            new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, a, table_reg, res1_reg);
            count++;
        } else if (op == LUAC_OP_GETTABLE && is_enc_rk(c, str_idx, str_count)) {
            int cidx = c - 256;
            ei_arg = &enc[cidx];
            DECRYPT(res1_reg);
            new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, a, b, res1_reg);
            count++;
        } else if (op == LUAC_OP_SELF && is_enc_rk(c, str_idx, str_count)) {
            int cidx = c - 256;
            ei_arg = &enc[cidx];
            DECRYPT(res1_reg);
            new_code[ni++] = LUAC_ABC(LUAC_OP_SELF, a, b, res1_reg);
            count++;
        } else if (op == LUAC_OP_SETTABUP) {
            int key_enc = is_enc_rk(b, str_idx, str_count);
            int val_enc = is_enc_rk(c, str_idx, str_count);
            if (key_enc || val_enc) {
                new_code[ni++] = LUAC_ABC(LUAC_OP_GETUPVAL, table_reg, a, 0);
                if (val_enc) {
                    ei_arg = &enc[c - 256];
                    DECRYPT(res1_reg);
                } else if (c >= 256) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, res1_reg, c - 256);
                } else {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, res1_reg, c, 0);
                }
                if (key_enc) {
                    ei_arg = &enc[b - 256];
                    DECRYPT(res2_reg);
                } else if (b >= 256) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, res2_reg, b - 256);
                } else {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, res2_reg, b, 0);
                }
                new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, table_reg, res2_reg, res1_reg);
                count++;
            } else {
                new_code[ni++] = ins;
            }
        } else if (op == LUAC_OP_SETTABLE) {
            int key_enc = is_enc_rk(b, str_idx, str_count);
            int val_enc = is_enc_rk(c, str_idx, str_count);
            if (key_enc || val_enc) {
                if (val_enc) {
                    ei_arg = &enc[c - 256];
                    DECRYPT(res1_reg);
                } else if (c >= 256) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, res1_reg, c - 256);
                } else {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, res1_reg, c, 0);
                }
                if (key_enc) {
                    ei_arg = &enc[b - 256];
                    DECRYPT(res2_reg);
                } else if (b >= 256) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, res2_reg, b - 256);
                } else {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, res2_reg, b, 0);
                }
                new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, a, res2_reg, res1_reg);
                count++;
            } else {
                new_code[ni++] = ins;
            }
        } else if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) {
            int b_enc = is_enc_rk(b, str_idx, str_count);
            int c_enc = is_enc_rk(c, str_idx, str_count);
            if (b_enc || c_enc) {
                int new_b = b, new_c = c;
                if (c_enc) {
                    ei_arg = &enc[c - 256];
                    DECRYPT(res1_reg);
                    new_c = res1_reg;
                }
                if (b_enc) {
                    ei_arg = &enc[b - 256];
                    DECRYPT(res2_reg);
                    new_b = res2_reg;
                }
                new_code[ni++] = LUAC_ABC(op, a, new_b, new_c);
                count++;
            } else {
                new_code[ni++] = ins;
            }
        } else {
            new_code[ni++] = ins;
        }

        insert_len[i] = (ni - start_ni) - 1;
        inserted_so_far += insert_len[i];
    }

    /* single-pass correct jump adjustment for JMP, FORPREP, FORLOOP:
       delta = insert_pos[target] - insert_pos[jmp] */
    for (int j = 0; j < ni; j++) {
        int op = new_code[j] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_TFORLOOP) {
            int a = (new_code[j] >> 6) & 0xFF;
            int bx = (new_code[j] >> 14) & 0x3FFFF;
            int sbx = bx - 131071;
            /* find original index of this instruction */
            int jmp_orig = -1;
            for (int k = 0; k < p->sizecode; k++) {
                if (k + insert_pos[k] == j) { jmp_orig = k; break; }
            }
            if (jmp_orig < 0) continue;
            int target_orig = jmp_orig + sbx + 1;
            if (target_orig < 0 || target_orig >= p->sizecode) continue;
            int delta = insert_pos[target_orig] - insert_pos[jmp_orig];
            if (delta != 0) {
                int new_sbx = sbx + delta;
                int new_bx = new_sbx + 131071;
                new_code[j] = LUAC_ABx(op, a, new_bx);
            }
        }
    }

    free(p->code);
    p->code = new_code;

    if (p->lineinfo && p->sizelineinfo > 0) {
        int *new_li = luac_alloc(sizeof(int) * ni);
        memset(new_li, 0, sizeof(int) * ni);
        for (int i = 0; i < p->sizecode && i < p->sizelineinfo; i++) {
            int pos = i + insert_pos[i];
            new_li[pos] = p->lineinfo[i];
        }
        free(p->lineinfo);
        p->lineinfo = new_li;
        p->sizelineinfo = ni;
    }

    p->sizecode = ni;

    for (int i = 0; i < str_count; i++) free(enc[str_idx[i]].byte_kidx);
    free(enc);
    free(str_idx);
    free(insert_pos);
    free(insert_len);
    return count;
}

int str_encrypt_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));

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
            count += encrypt_function(L, list[i]);
    }
    lua_pushinteger(L, count);
    return 1;
}
