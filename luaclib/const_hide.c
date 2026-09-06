/*
** const_hide.c - Constant pool hiding (C implementation)
** Concatenates multiple string constants into one blob, restores via substring at runtime.
*/
#include "obf_util.h"

#define SUB_SRC "return function(s, i, j) return s:sub(i, j) end"

typedef struct { int offset; int endpos; int off_kidx; int endp_kidx; } HideInfo;

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

    /* add substring sub-proto */
    luac_Proto *sub_raw = NULL;
    if (!obf_compile_subproto(L, SUB_SRC, &sub_raw)) { free(str_idx); free(info); return 0; }
    int sub_pidx = obf_add_subproto(L, p, sub_raw);

    /* register allocation: TMP/KEY must be beyond sub function's stack frame */
    int sub_maxstack = sub_raw->maxstacksize ? sub_raw->maxstacksize : 6;
    int base_reg = p->maxstacksize;
    int SUB_REG = base_reg;
    int ARG1_REG = base_reg + 1;
    int ARG2_REG = base_reg + 2;
    int ARG3_REG = base_reg + 3;
    int frame_end = base_reg + sub_maxstack + 16;
    int TMP_REG = frame_end;
    int KEY_REG = frame_end + 1;
    obf_ensure_stack(p, KEY_REG + 1);

    /* First pass: build new code, track insertions */
    int *insert_pos = luac_alloc(sizeof(int) * p->sizecode);
    int *insert_len = luac_alloc(sizeof(int) * p->sizecode);
    memset(insert_pos, 0, sizeof(int) * p->sizecode);
    memset(insert_len, 0, sizeof(int) * p->sizecode);

    unsigned int *new_code = luac_alloc(sizeof(unsigned int) * (p->sizecode * 16 + 64));
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
        unsigned int seq[24];

        if (op == LUAC_OP_LOADK) {
            int bx = (int)(ins >> 14);
            if (bx < p->sizek && info[bx].offset > 0) {
                seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[bx].off_kidx);
                seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[bx].endp_kidx);
                seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                if (a != SUB_REG) seq[seq_len++] = LUAC_ABC(LUAC_OP_MOVE, a, SUB_REG, 0);
                count++;
            }
        } else if (op == LUAC_OP_GETTABLE && c >= 256 && info[c-256].offset > 0) {
            int kidx = c - 256;
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[kidx].off_kidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[kidx].endp_kidx);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_GETTABLE, a, b, SUB_REG);
            count++;
        } else if (op == LUAC_OP_SETTABLE) {
            int b_hid = (b >= 256 && b-256 < p->sizek && info[b-256].offset > 0);
            int c_hid = (c >= 256 && c-256 < p->sizek && info[c-256].offset > 0);
            if (b_hid || c_hid) {
                if (b_hid && c_hid) {
                    int kidx = b - 256, vidx = c - 256;
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[kidx].off_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[kidx].endp_kidx);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_MOVE, KEY_REG, SUB_REG, 0);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[vidx].off_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[vidx].endp_kidx);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, a, KEY_REG, SUB_REG);
                } else if (b_hid) {
                    int kidx = b - 256;
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[kidx].off_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[kidx].endp_kidx);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, a, SUB_REG, c);
                } else {
                    int vidx = c - 256;
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[vidx].off_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[vidx].endp_kidx);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, a, b, SUB_REG);
                }
                count++;
            }
        } else if (op == LUAC_OP_GETTABUP && c >= 256 && info[c-256].offset > 0) {
            int kidx = c - 256;
            seq[seq_len++] = LUAC_ABC(LUAC_OP_GETUPVAL, TMP_REG, b, 0);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[kidx].off_kidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[kidx].endp_kidx);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_GETTABLE, a, TMP_REG, SUB_REG);
            count++;
        } else if (op == LUAC_OP_SETTABUP) {
            int b_hid = (b >= 256 && b-256 < p->sizek && info[b-256].offset > 0);
            int c_hid = (c >= 256 && c-256 < p->sizek && info[c-256].offset > 0);
            if (b_hid || c_hid) {
                seq[seq_len++] = LUAC_ABC(LUAC_OP_GETUPVAL, TMP_REG, a, 0);
                if (b_hid && c_hid) {
                    int kidx = b - 256, vidx = c - 256;
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[kidx].off_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[kidx].endp_kidx);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_MOVE, KEY_REG, SUB_REG, 0);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[vidx].off_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[vidx].endp_kidx);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, TMP_REG, KEY_REG, SUB_REG);
                } else if (b_hid) {
                    int kidx = b - 256;
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[kidx].off_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[kidx].endp_kidx);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, TMP_REG, SUB_REG, c);
                } else {
                    int vidx = c - 256;
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[vidx].off_kidx);
                    seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[vidx].endp_kidx);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
                    seq[seq_len++] = LUAC_ABC(LUAC_OP_SETTABLE, TMP_REG, b, SUB_REG);
                }
                count++;
            }
        } else if (op == LUAC_OP_SELF && c >= 256 && info[c-256].offset > 0) {
            int kidx = c - 256;
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG1_REG, blob_kidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_CLOSURE, SUB_REG, sub_pidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG2_REG, info[kidx].off_kidx);
            seq[seq_len++] = LUAC_ABx(LUAC_OP_LOADK, ARG3_REG, info[kidx].endp_kidx);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_CALL, SUB_REG, 4, 2);
            seq[seq_len++] = LUAC_ABC(LUAC_OP_SELF, a, b, SUB_REG);
            count++;
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

    /* Second pass: adjust jumps */
    for (int i = 0; i < p->sizecode; i++) {
        if (insert_len[i] > 0) {
            int new_pos = i + insert_pos[i] + 1; /* 1-based, after original instruction */
            obf_adjust_jumps_insert(new_code, ni, new_pos, insert_len[i]);
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
