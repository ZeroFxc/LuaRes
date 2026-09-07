/*
** const_hide.c - Constant pool hiding (C implementation)
** Concatenates multiple string constants into one blob, restores via inline string.sub call.
** Uses inline C-function call (string.sub) instead of Lua sub-proto to avoid stack frame
** overlap when later modules increase sub-proto maxstacksize.
*/
#include "obf_util.h"

typedef struct { int offset; int endpos; int off_kidx; int endp_kidx; } HideInfo;

/* emit inline string.sub(blob, off, end) into result_reg.
   Uses registers: env_r, str_r, sub_r, sub_r+1, sub_r+2, sub_r+3.
   blob/off/end loaded directly into arg registers sub_r+1..sub_r+3. */
static void emit_sub_call(unsigned int *seq, int *seq_len,
                          int env_r, int str_r, int sub_r,
                          int blob_kidx, int off_kidx, int end_kidx,
                          int k_string, int k_sub, int result_reg) {
    seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_GETUPVAL, env_r, 0, 0);
    seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_GETTABLE, str_r, env_r, k_string + 256);
    seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_GETTABLE, sub_r, str_r, k_sub + 256);
    seq[(*seq_len)++] = LUAC_ABx(LUAC_OP_LOADK, sub_r + 1, blob_kidx);
    seq[(*seq_len)++] = LUAC_ABx(LUAC_OP_LOADK, sub_r + 2, off_kidx);
    seq[(*seq_len)++] = LUAC_ABx(LUAC_OP_LOADK, sub_r + 3, end_kidx);
    seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_CALL, sub_r, 4, 2);
    if (result_reg != sub_r)
        seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_MOVE, result_reg, sub_r, 0);
}

static int process_function(lua_State *L, luac_Proto *p) {
    if (!p->k_str || p->sizek < 2) return 0;

    /* collect string constant indices */
    int *str_idx = luac_alloc(sizeof(int) * p->sizek);
    int str_count = 0;
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TSHRSTR || p->k_tag[i] == LUA_TLNGSTR) && p->k_str[i]) {
            str_idx[str_count++] = i;
        }
    }
    if (str_count < 2) { free(str_idx); return 0; }

    /* build blob and offset map */
    HideInfo *info = luac_alloc(sizeof(HideInfo) * p->sizek);
    memset(info, 0, sizeof(HideInfo) * p->sizek);
    size_t blob_len = 0;
    for (int i = 0; i < str_count; i++) blob_len += (size_t)p->k_str_len[str_idx[i]];
    char *blob = luac_alloc(blob_len + 1);
    size_t pos = 0;
    int offset = 1; /* Lua string.sub is 1-based */
    for (int i = 0; i < str_count; i++) {
        int idx = str_idx[i];
        int len = p->k_str_len[idx];
        memcpy(blob + pos, p->k_str[idx], len);
        pos += len;
        info[idx].offset = offset;
        info[idx].endpos = offset + len - 1;
        offset += len;
    }
    blob[blob_len] = '\0';

    /* add blob constant */
    int blob_kidx = obf_add_k_string(p, blob, blob_len);
    free(blob);
    p->k_str_len[blob_kidx] = -(int)blob_len;  /* mark as const_hide blob */

    /* add "string" and "sub" constants for inline call */
    int k_string = obf_add_k_string(p, "string", 6);
    int k_sub = obf_add_k_string(p, "sub", 3);

    /* add offset/endpos number constants */
    for (int i = 0; i < str_count; i++) {
        int idx = str_idx[i];
        info[idx].off_kidx = obf_add_k_number(p, (double)info[idx].offset);
        info[idx].endp_kidx = obf_add_k_number(p, (double)info[idx].endpos);
    }

    /* set original string constants to nil */
    for (int i = 0; i < str_count; i++) {
        int idx = str_idx[i];
        free(p->k_str[idx]);
        p->k_str[idx] = NULL;
        p->k_str_len[idx] = 0;
        p->k_tag[idx] = LUA_TNIL;
    }

    /* register allocation for inline string.sub call */
    int base_reg = p->maxstacksize;
    int ENV_REG = base_reg;
    int STR_REG = base_reg + 1;
    int SUB_REG = base_reg + 2;
    int TMP_REG = base_reg + 6;  /* beyond sub_r+3 */
    int KEY_REG = base_reg + 7;
    int VAL_REG = base_reg + 8;
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: base=%d env=%d str=%d sub=%d tmp=%d key=%d val=%d\n", base_reg, ENV_REG, STR_REG, SUB_REG, TMP_REG, KEY_REG, VAL_REG);
#endif
    if (VAL_REG + 1 > 250) { free(str_idx); free(info); return 0; }
    obf_ensure_stack(p, VAL_REG + 1);

    /* First pass: build new code, track insertions */
    int *insert_pos = luac_alloc(sizeof(int) * p->sizecode);
    int *insert_len = luac_alloc(sizeof(int) * p->sizecode);
    memset(insert_pos, 0, sizeof(int) * p->sizecode);
    memset(insert_len, 0, sizeof(int) * p->sizecode);

    /* each hidden string can expand to up to 20 instructions (SETTABUP with both key+val hidden: 2*8+1=17) */
    int max_new = p->sizecode + str_count * 20 + 64;
    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * max_new);
    int ni = 0;
    int count = 0;
    int inserted_so_far = 0;

    for (int i = 0; i < p->sizecode; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;
        int b = (ins >> 23) & 0x1FF;
        int c = (ins >> 14) & 0x1FF;

        int seq_len = 0;
        unsigned int seq[32];

        if (op == LUAC_OP_LOADK) {
            int bx = (int)(ins >> 14);
            if (bx < p->sizek && info[bx].offset > 0) {
                emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                    blob_kidx, info[bx].off_kidx, info[bx].endp_kidx,
                    k_string, k_sub, a);
                count++;
            }
        } else if (op == LUAC_OP_GETTABLE && c >= 256 && info[c-256].offset > 0) {
            int kidx = c - 256;
            emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                k_string, k_sub, TMP_REG);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_GETTABLE, a, b, TMP_REG);
            count++;
        } else if (op == LUAC_OP_SETTABLE) {
            int b_hid = (b >= 256 && b-256 < p->sizek && info[b-256].offset > 0);
            int c_hid = (c >= 256 && c-256 < p->sizek && info[c-256].offset > 0);
            if (b_hid || c_hid) {
                if (b_hid && c_hid) {
                    int kidx = b - 256, vidx = c - 256;
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                        k_string, k_sub, KEY_REG);
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[vidx].off_kidx, info[vidx].endp_kidx,
                        k_string, k_sub, TMP_REG);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, a, KEY_REG, TMP_REG);
                } else if (b_hid) {
                    int kidx = b - 256;
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                        k_string, k_sub, KEY_REG);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, a, KEY_REG, c);
                } else {
                    int vidx = c - 256;
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[vidx].off_kidx, info[vidx].endp_kidx,
                        k_string, k_sub, TMP_REG);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, a, b, TMP_REG);
                }
                count++;
            }
        } else if (op == LUAC_OP_GETTABUP && c >= 256 && info[c-256].offset > 0) {
            int kidx = c - 256;
            seq[seq_len++] = LUAC_ABC(LUAC_OP_GETUPVAL, TMP_REG, b, 0);
            emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                k_string, k_sub, KEY_REG);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_GETTABLE, a, TMP_REG, KEY_REG);
            count++;
        } else if (op == LUAC_OP_SETTABUP) {
            int b_hid = (b >= 256 && b-256 < p->sizek && info[b-256].offset > 0);
            int c_hid = (c >= 256 && c-256 < p->sizek && info[c-256].offset > 0);
            if (b_hid || c_hid) {
                seq[seq_len++] = LUAC_ABC(LUAC_OP_GETUPVAL, TMP_REG, a, 0);
                if (b_hid && c_hid) {
                    int kidx = b - 256, vidx = c - 256;
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                        k_string, k_sub, KEY_REG);
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[vidx].off_kidx, info[vidx].endp_kidx,
                        k_string, k_sub, VAL_REG);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, TMP_REG, KEY_REG, VAL_REG);
                } else if (b_hid) {
                    int kidx = b - 256;
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                        k_string, k_sub, KEY_REG);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, TMP_REG, KEY_REG, c);
                } else {
                    int vidx = c - 256;
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[vidx].off_kidx, info[vidx].endp_kidx,
                        k_string, k_sub, VAL_REG);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, TMP_REG, b, VAL_REG);
                }
                count++;
            }
        } else if (op == LUAC_OP_SELF && c >= 256 && info[c-256].offset > 0) {
            int kidx = c - 256;
            emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                k_string, k_sub, TMP_REG);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_SELF, a, b, TMP_REG);
            count++;
        } else if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) {
            int b_hid = (b >= 256 && b-256 < p->sizek && info[b-256].offset > 0);
            int c_hid = (c >= 256 && c-256 < p->sizek && info[c-256].offset > 0);
            if (b_hid || c_hid) {
                int new_b = b, new_c = c;
                if (b_hid) {
                    int kidx = b - 256;
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                        k_string, k_sub, TMP_REG);
                    new_b = TMP_REG;
                }
                if (c_hid) {
                    int kidx = c - 256;
                    emit_sub_call(seq, &seq_len, ENV_REG, STR_REG, SUB_REG,
                        blob_kidx, info[kidx].off_kidx, info[kidx].endp_kidx,
                        k_string, k_sub, KEY_REG);
                    new_c = KEY_REG;
                }
                seq[seq_len++] = LUAC_ABC(op, a, new_b, new_c);
                count++;
            }
        }

        insert_pos[i] = inserted_so_far;
        if (seq_len > 0) {
            for (int j = 0; j < seq_len; j++) new_code[ni++] = seq[j];
            insert_len[i] = seq_len - 1;
            inserted_so_far += seq_len - 1;
        } else {
            new_code[ni++] = ins;
            insert_len[i] = 0;
        }
    }

    /* Second pass: adjust all jumps in one pass. */
    {
        int total_inserted = inserted_so_far;
        for (int i = 0; i < ni; i++) {
            int op = new_code[i] & 0x3F;
            if (op != LUAC_OP_JMP && op != LUAC_OP_FORLOOP && op != LUAC_OP_FORPREP && op != LUAC_OP_TFORLOOP) continue;
            int sbx = (int)(new_code[i] >> 14) - 131071;
            int old_jmp = -1;
            for (int j = 0; j < p->sizecode; j++) {
                if (j + insert_pos[j] == i) { old_jmp = j; break; }
            }
            if (old_jmp < 0) continue;
            int old_tgt = old_jmp + sbx + 1;
            int tgt_insert = (old_tgt >= 0 && old_tgt < p->sizecode) ? insert_pos[old_tgt] : total_inserted;
            int delta = tgt_insert - insert_pos[old_jmp];
            if (delta) {
                new_code[i] = (new_code[i] & 0x3FFF) | ((unsigned int)(sbx + delta + 131071) << 14);
            }
        }
    }

    free(p->code);
    p->code = new_code;
    p->sizecode = ni;

    free(str_idx);
    free(info);
    free(insert_pos);
    free(insert_len);
    return count;
}

int const_hide_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    /* two-pass: collect all protos first, then process */
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
        count += process_function(L, list[i]);
    }
    lua_pushinteger(L, count);
    return 1;
}
