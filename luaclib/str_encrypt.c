/*
** str_encrypt.c - String constant encryption (C implementation, v6 shared decryptor)
** Mode: encrypted strings stored as binary string constants in K table.
** A single shared decrypt function is installed in _ENV.__ds once per main proto.
** Each decrypt site: GETTABUP(func) + LOADK(enc_str) + LOADK(key) + CALL -> 4 insns.
** No per-site table rebuild, no per-byte integer constants in K table.
*/
#include <time.h>
#include <string.h>
#include <stdio.h>
#include "obf_util.h"

/* shared random dsname (16 raw bytes), per-proto constant copies */
static char g_rndkey[16];

#define STR_DEBUG 0

/* === shared decrypt function source (compiled to proto once) === */
static const char *DECRYPTOR_SRC =
"return function(enc, key)\n"
"  local r = \"\"\n"
"  local i = 1\n"
"  local n = #enc\n"
"  while i <= n do\n"
"    local b = string.byte(enc, i) ~ key\n"
"    r = r .. string.char(b)\n"
"    i = i + 1\n"
"  end\n"
"  return r\n"
"end\n";

static int is_enc_str_idx(int idx, int *str_idx, int str_count) {
    for (int i = 0; i < str_count; i++)
        if (str_idx[i] == idx) return 1;
    return 0;
}

static int is_enc_rk(int rk, int *str_idx, int str_count) {
    if (rk < 256) return 0;
    return is_enc_str_idx(rk - 256, str_idx, str_count);
}

/* encrypt strings in one proto: replace each string with XORed binary string */
static int encrypt_strings_only(luac_Proto *p, int *str_idx, int str_count,
                                  int *enc_key_idx) {
    if (str_count == 0) return 0;
    unsigned int seed = (unsigned int)time(NULL) ^ (unsigned int)(size_t)p;
    int count = 0;
    for (int i = 0; i < str_count; i++) {
        int idx = str_idx[i];
        int len = p->k_str_len[idx];
        const char *s = p->k_str[idx];
        if (!s || len <= 1) continue;
        seed = seed * 1103515245 + 12345;
        int key = (int)(seed & 0xFF);
        if (key == 0) key = 1;
        /* encrypt each byte in-place */
        char *enc = luac_alloc(len);
        for (int j = 0; j < len; j++) {
            enc[j] = (char)((unsigned char)s[j] ^ (unsigned char)key);
        }
        /* replace K entry with encrypted binary string */
        free(p->k_str[idx]);
        p->k_str[idx] = enc;
        p->k_str_len[idx] = len;
        p->k_tag[idx] = LUA_TSHRSTR;
        /* store key as integer constant */
        enc_key_idx[idx] = obf_add_k_integer(p, (long long)key);
        count++;
    }
    return count;
}

/* rewrite instructions that reference encrypted strings to call shared decryptor */
static int rewrite_decrypt_sites(lua_State *L, luac_Proto *p,
                                   int *str_idx, int str_count,
                                   int *enc_key_idx,
                                   int decryptor_proto_idx,
                                   int dsname_kidx) {
    if (str_count == 0) return 0;

    /* count sites to estimate new code size */
    int site_count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        int b = (p->code[i] >> 23) & 0x1FF;
        int c = (p->code[i] >> 14) & 0x1FF;
        if (op == LUAC_OP_LOADK) {
            int bx = (int)(p->code[i] >> 14);
            if (is_enc_str_idx(bx, str_idx, str_count)) site_count++;
        } else if ((op == LUAC_OP_GETTABUP || op == LUAC_OP_GETTABLE || op == LUAC_OP_SELF) && c >= 256) {
            if (is_enc_str_idx(c - 256, str_idx, str_count)) site_count++;
        } else if (op == LUAC_OP_SETTABUP || op == LUAC_OP_SETTABLE) {
            int hit = 0;
            if (b >= 256 && is_enc_str_idx(b - 256, str_idx, str_count)) hit = 1;
            if (!hit && c >= 256 && is_enc_str_idx(c - 256, str_idx, str_count)) hit = 1;
            if (hit) site_count++;
        } else if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) {
            int hit = 0;
            if (b >= 256 && is_enc_str_idx(b - 256, str_idx, str_count)) hit = 1;
            if (!hit && c >= 256 && is_enc_str_idx(c - 256, str_idx, str_count)) hit = 1;
            if (hit) site_count++;
        }
    }
    if (site_count == 0) return 0;

    int base = p->maxstacksize;
    int func_reg = base;
    int enc_reg = base + 1;
    int key_reg = base + 2;
    int res1_reg = base + 3;
    int res2_reg = base + 4;
    int table_reg = base + 5;
    obf_ensure_stack(p, base + 6);

    /* max 8 insns per site (LOADK+LOADK+GETTABUP+CALL for simple, more for SETTABLE) */
    int max_new = p->sizecode + site_count * 10 + 64;
    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * max_new);
    int ni = 0;

    int *insert_pos = luac_alloc(sizeof(int) * (p->sizecode + 1));
    int *insert_len = luac_alloc(sizeof(int) * (p->sizecode + 1));
    memset(insert_pos, 0, sizeof(int) * (p->sizecode + 1));
    memset(insert_len, 0, sizeof(int) * (p->sizecode + 1));
    int inserted_so_far = 0;

    /* emit decrypt call: func = _ENV.__ds; func(enc_str, key) -> result_reg */
    /* RK overflow guard: GETTABUP C is RK (9-bit); if dsname_kidx >= 256 the
       RK encoding overflows into B. Load the name into enc_reg first, then
       overwrite enc_reg with the encrypted string (safe order). */
    #define EMIT_DECRYPT(result_reg, str_kidx) do { \
        if (dsname_kidx < 256) { \
            new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABUP, func_reg, 0, 256 + dsname_kidx); \
        } else { \
            new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, enc_reg, dsname_kidx); \
            new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABUP, func_reg, 0, enc_reg); \
        } \
        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, enc_reg, str_kidx); \
        new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, key_reg, enc_key_idx[str_kidx]); \
        new_code[ni++] = LUAC_ABC(LUAC_OP_CALL, func_reg, 3, 2); \
        if ((result_reg) != func_reg) { \
            new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, (result_reg), func_reg, 0); \
        } \
    } while(0)

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
            if (is_enc_str_idx(bx, str_idx, str_count)) {
                EMIT_DECRYPT(a, bx);
            } else {
                new_code[ni++] = ins;
            }
        } else if (op == LUAC_OP_GETTABUP && is_enc_rk(c, str_idx, str_count)) {
            int cidx = c - 256;
            new_code[ni++] = LUAC_ABC(LUAC_OP_GETUPVAL, table_reg, b, 0);
            EMIT_DECRYPT(res1_reg, cidx);
            new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, a, table_reg, res1_reg);
        } else if (op == LUAC_OP_GETTABLE && is_enc_rk(c, str_idx, str_count)) {
            int cidx = c - 256;
            EMIT_DECRYPT(res1_reg, cidx);
            new_code[ni++] = LUAC_ABC(LUAC_OP_GETTABLE, a, b, res1_reg);
        } else if (op == LUAC_OP_SELF && is_enc_rk(c, str_idx, str_count)) {
            int cidx = c - 256;
            EMIT_DECRYPT(res1_reg, cidx);
            new_code[ni++] = LUAC_ABC(LUAC_OP_SELF, a, b, res1_reg);
        } else if (op == LUAC_OP_SETTABUP) {
            int key_enc = is_enc_rk(b, str_idx, str_count);
            int val_enc = is_enc_rk(c, str_idx, str_count);
            if (key_enc || val_enc) {
                new_code[ni++] = LUAC_ABC(LUAC_OP_GETUPVAL, table_reg, a, 0);
                if (val_enc) {
                    EMIT_DECRYPT(res1_reg, c - 256);
                } else if (c >= 256) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, res1_reg, c - 256);
                } else {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, res1_reg, c, 0);
                }
                if (key_enc) {
                    EMIT_DECRYPT(res2_reg, b - 256);
                } else if (b >= 256) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, res2_reg, b - 256);
                } else {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, res2_reg, b, 0);
                }
                new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, table_reg, res2_reg, res1_reg);
            } else {
                new_code[ni++] = ins;
            }
        } else if (op == LUAC_OP_SETTABLE) {
            int key_enc = is_enc_rk(b, str_idx, str_count);
            int val_enc = is_enc_rk(c, str_idx, str_count);
            if (key_enc || val_enc) {
                if (val_enc) {
                    EMIT_DECRYPT(res1_reg, c - 256);
                } else if (c >= 256) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, res1_reg, c - 256);
                } else {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, res1_reg, c, 0);
                }
                if (key_enc) {
                    EMIT_DECRYPT(res2_reg, b - 256);
                } else if (b >= 256) {
                    new_code[ni++] = LUAC_ABx(LUAC_OP_LOADK, res2_reg, b - 256);
                } else {
                    new_code[ni++] = LUAC_ABC(LUAC_OP_MOVE, res2_reg, b, 0);
                }
                new_code[ni++] = LUAC_ABC(LUAC_OP_SETTABLE, a, res2_reg, res1_reg);
            } else {
                new_code[ni++] = ins;
            }
        } else if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) {
            int b_enc = is_enc_rk(b, str_idx, str_count);
            int c_enc = is_enc_rk(c, str_idx, str_count);
            if (b_enc || c_enc) {
                int new_b = b, new_c = c;
                if (c_enc) {
                    EMIT_DECRYPT(res1_reg, c - 256);
                    new_c = res1_reg;
                }
                if (b_enc) {
                    EMIT_DECRYPT(res2_reg, b - 256);
                    new_b = res2_reg;
                }
                new_code[ni++] = LUAC_ABC(op, a, new_b, new_c);
            } else {
                new_code[ni++] = ins;
            }
        } else {
            new_code[ni++] = ins;
        }

        insert_len[i] = (ni - start_ni) - 1;
        inserted_so_far += insert_len[i];
    }

    /* fix jumps */
    for (int j = 0; j < ni; j++) {
        int op = new_code[j] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORPREP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_TFORLOOP) {
            int a = (new_code[j] >> 6) & 0xFF;
            int bx = (new_code[j] >> 14) & 0x3FFFF;
            int sbx = bx - 131071;
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
    free(insert_pos);
    free(insert_len);
    return site_count;
}

/* install decryptor: compile shared function, add as subproto, emit CLOSURE+SETTABUP at main proto start.
   The global key is a random 16-byte binary string (not printable), so it cannot be guessed or intercepted by name. */
static int install_decryptor(lua_State *L, luac_Proto *main_p,
                               int *out_proto_idx, int *out_dsname_kidx) {
    luac_Proto *dec = NULL;
    if (!obf_compile_subproto(L, DECRYPTOR_SRC, &dec)) {
        return 0;
    }
    int idx = obf_add_subproto(L, main_p, dec);
    if (idx < 0) return 0;

    /* generate random 16-byte binary key (non-printable, unguessable) */
    static unsigned int rng_state = 0;
    if (rng_state == 0) rng_state = (unsigned int)time(NULL) ^ (unsigned int)(size_t)main_p;
    for (int i = 0; i < 16; i++) {
        rng_state = rng_state * 1103515245 + 12345;
        g_rndkey[i] = (char)((rng_state >> 16) & 0xFF);
    }
    int dsname_kidx = obf_add_k_string(main_p, g_rndkey, 16);

    /* insert at position 1 (1-based): CLOSURE R(tmp), idx; SETTABUP upval0[const rndkey] = R(tmp) */
    int tmp_reg = main_p->maxstacksize;
    obf_ensure_stack(main_p, tmp_reg + 1);

    /* RK overflow guard: SETTABUP B is RK (9-bit); dsname_kidx >= 256 would
       overflow into A/C fields. Load the name into an extra register first. */
    if (dsname_kidx < 256) {
        unsigned int ins[2];
        ins[0] = LUAC_ABx(LUAC_OP_CLOSURE, tmp_reg, idx);
        ins[1] = LUAC_ABC(LUAC_OP_SETTABUP, 0, 256 + dsname_kidx, tmp_reg);
        obf_code_insert(main_p, 1, ins, 2);
    } else {
        int name_reg = main_p->maxstacksize;
        obf_ensure_stack(main_p, name_reg + 1);
        unsigned int ins[3];
        ins[0] = LUAC_ABx(LUAC_OP_LOADK, name_reg, dsname_kidx);
        ins[1] = LUAC_ABx(LUAC_OP_CLOSURE, tmp_reg, idx);
        ins[2] = LUAC_ABC(LUAC_OP_SETTABUP, 0, name_reg, tmp_reg);
        obf_code_insert(main_p, 1, ins, 3);
    }

    *out_proto_idx = idx;
    *out_dsname_kidx = dsname_kidx;
    return 1;
}

int str_encrypt_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    /* collect all protos */
    int cap = 1024;
    luac_Proto **list = luac_alloc(sizeof(luac_Proto *) * cap);
    int list_count = 0;
    luac_Proto **stk = luac_alloc(sizeof(luac_Proto *) * cap);
    int sp = 0;
    stk[sp++] = p;
    while (sp > 0) {
        luac_Proto *cur = stk[--sp];
        if (list_count >= cap) {
            cap *= 2;
            list = realloc(list, sizeof(luac_Proto *) * cap);
            stk = realloc(stk, sizeof(luac_Proto *) * cap);
        }
        list[list_count++] = cur;
        if (cur->p) {
            for (int j = cur->sizep - 1; j >= 0; j--)
                stk[sp++] = cur->p[j];
        }
    }

    /* first pass: encrypt strings in all protos, collect str_idx per proto */
    int total_encrypted = 0;
    int **all_str_idx = luac_alloc(sizeof(int *) * list_count);
    int *all_str_count = luac_alloc(sizeof(int) * list_count);
    int **all_key_idx = luac_alloc(sizeof(int *) * list_count);

    for (int pi = 0; pi < list_count; pi++) {
        luac_Proto *cur = list[pi];
        int *str_idx = luac_alloc(sizeof(int) * cur->sizek);
        int str_count = 0;
        for (int i = 0; i < cur->sizek; i++) {
            if ((cur->k_tag[i] == LUA_TSHRSTR || cur->k_tag[i] == LUA_TLNGSTR) && cur->k_str[i]
                && cur->k_str_len[i] > 1)
                str_idx[str_count++] = i;
        }
        all_str_idx[pi] = str_idx;
        all_str_count[pi] = str_count;
        all_key_idx[pi] = luac_alloc(sizeof(int) * cur->sizek);
        memset(all_key_idx[pi], 0, sizeof(int) * cur->sizek);
        if (str_count > 0) {
            total_encrypted += encrypt_strings_only(cur, str_idx, str_count, all_key_idx[pi]);
        }
    }

#if STR_DEBUG
    fprintf(stderr, "[STR] total_encrypted=%d list_count=%d\n", total_encrypted, list_count);
#endif
    if (total_encrypted == 0) {
        for (int pi = 0; pi < list_count; pi++) {
            free(all_str_idx[pi]);
            free(all_key_idx[pi]);
        }
        free(all_str_idx); free(all_str_count); free(all_key_idx);
        free(list); free(stk);
        lua_pushinteger(L, 0);
        return 1;
    }

    /* install shared decryptor in main proto */
    int dec_idx = 0, dsname_kidx = 0;
#if STR_DEBUG
    fprintf(stderr, "[STR] before install sizek=%d sizep=%d maxstack=%d\n", p->sizek, p->sizep, p->maxstacksize);
#endif
    if (!install_decryptor(L, p, &dec_idx, &dsname_kidx)) {
        lua_pushinteger(L, 0);
        return 1;
    }

    /* Re-collect protos. install_decryptor -> obf_add_subproto rebuilt the
       p table via luac_push_proto, which deep-copies each sub-proto struct
       and NULLs the original C pointers (ownership transfer). The first
       list is now dangling; re-collect with the same DFS order (install
       only appends the decryptor at the end, so the first list_count
       entries are identical to the first collection). */
    free(list); free(stk);
    cap = 1024;
    list = luac_alloc(sizeof(luac_Proto *) * cap);
    stk = luac_alloc(sizeof(luac_Proto *) * cap);
    int list2_count = 0;
    sp = 0;
    stk[sp++] = p;
    while (sp > 0) {
        luac_Proto *cur = stk[--sp];
        if (list2_count >= cap) {
            cap *= 2;
            list = realloc(list, sizeof(luac_Proto *) * cap);
            stk = realloc(stk, sizeof(luac_Proto *) * cap);
        }
        list[list2_count++] = cur;
        if (cur->p) for (int j = cur->sizep - 1; j >= 0; j--) stk[sp++] = cur->p[j];
    }

    /* second pass: rewrite decrypt sites in all protos */
    int total_sites = 0;
#if STR_DEBUG
    fprintf(stderr, "[STR] after install dec_idx=%d dsname_kidx=%d sizek=%d sizep=%d maxstack=%d\n", dec_idx, dsname_kidx, p->sizek, p->sizep, p->maxstacksize);
#endif
    /* use the FIRST list_count: the decryptor appended at the end has no
       entry in all_str_count/all_key_idx arrays */
    for (int pi = 0; pi < list_count; pi++) {
        if (all_str_count[pi] > 0) {
#if STR_DEBUG
            fprintf(stderr, "[STR] rewrite proto %d: code=%d sizek=%d sites=%d maxstack=%d lineinfo=%d codeptr=%p\n",
                pi, list[pi]->sizecode, list[pi]->sizek, all_str_count[pi], list[pi]->maxstacksize,
                list[pi]->sizelineinfo, (void*)list[pi]->code);
#endif
            int before_code = list[pi]->sizecode;
            /* dsname constant lives in the MAIN proto's pool; sub-protos need
               their own copy so the LOADK/GETTABUP at decrypt sites resolve. */
            int proto_dsname = (pi == 0) ? dsname_kidx
                                         : obf_add_k_string(list[pi], g_rndkey, 16);
            total_sites += rewrite_decrypt_sites(L, list[pi],
                all_str_idx[pi], all_str_count[pi], all_key_idx[pi],
                dec_idx, proto_dsname);
#if STR_DEBUG
            fprintf(stderr, "[STR] rewrite proto %d: code %d -> %d (sites %d)\n", pi, before_code, list[pi]->sizecode, all_str_count[pi]);
#endif
        }
    }

    for (int pi = 0; pi < list_count; pi++) {
        free(all_str_idx[pi]);
        free(all_key_idx[pi]);
    }
    free(all_str_idx); free(all_str_count); free(all_key_idx);
    free(list); free(stk); /* list2 (re-collected) also freed here */

    lua_pushinteger(L, total_sites);
    return 1;
}
