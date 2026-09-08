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
    seq[(*seq_len)++] = LUAC_ABx(LUAC_OP_LOADK, sub_r + 4, k_string);
    seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_GETTABLE, str_r, env_r, sub_r + 4);
    seq[(*seq_len)++] = LUAC_ABx(LUAC_OP_LOADK, sub_r + 4, k_sub);
    seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_GETTABLE, sub_r, str_r, sub_r + 4);
    seq[(*seq_len)++] = LUAC_ABx(LUAC_OP_LOADK, sub_r + 1, blob_kidx);
    seq[(*seq_len)++] = LUAC_ABx(LUAC_OP_LOADK, sub_r + 2, off_kidx);
    seq[(*seq_len)++] = LUAC_ABx(LUAC_OP_LOADK, sub_r + 3, end_kidx);
    seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_CALL, sub_r, 4, 2);
    if (result_reg != sub_r)
        seq[(*seq_len)++] = LUAC_ABC(LUAC_OP_MOVE, result_reg, sub_r, 0);
}

static int process_function(lua_State *L, luac_Proto *p) {
#if defined(CONST_HIDE_DEBUG)
    {
        void *t = malloc(1024);
        fprintf(stderr, "const_hide: ENTRY probe malloc(1024)=%p sizek=%d\n", t, p->sizek);
        if (t) free(t);
    }
    fprintf(stderr, "const_hide: process_func sizek=%d upvals=%d upval_name=%p",
        p->sizek, p->sizeupvalues, (void*)p->upval_name);
    if (p->sizeupvalues > 0 && p->upval_name && p->upval_name[0]) {
        fprintf(stderr, " upval0_len=%d upval0=\'%.*s\'",
            p->upval_name_len[0], p->upval_name_len[0], p->upval_name[0]);
    }
    fprintf(stderr, "\n");
#endif
    if (!p->k_str || p->sizek < 2) return 0;
    /* require _ENV as first upvalue for inline string.sub call */
    if (p->sizeupvalues < 1 || !p->upval_name || !p->upval_name[0] ||
        p->upval_name_len[0] != 4 || memcmp(p->upval_name[0], "_ENV", 4) != 0) return 0;

    /* Register budget check MUST happen before any mutation.
       base_reg sits above every register the code can touch; maxstacksize
       is normally that high-water mark, but some inputs carry a broken
       (too small) maxstacksize while the code reaches far higher registers,
       so scan the code. Skipping here leaves the proto untouched. */
    int base_reg = p->maxstacksize;
    int max_reg = -1;
    for (int i = 0; i < p->sizecode; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;
        if (a > max_reg) max_reg = a;
        if (op != LUAC_OP_JMP && op != LUAC_OP_EXTRAARG &&
            op != LUAC_OP_FORLOOP && op != LUAC_OP_FORPREP && op != LUAC_OP_TFORLOOP) {
            int b = (ins >> 23) & 0x1FF;
            int c = (ins >> 14) & 0x1FF;
            if (b < 256 && b > max_reg) max_reg = b;
            if (c < 256 && c > max_reg) max_reg = c;
        }
    }
    if (max_reg + 1 > base_reg) base_reg = max_reg + 1;
    if (base_reg + 10 > 250) return 0;  /* VAL_REG+1 == base_reg+10 must fit */

    /* collect string constant indices */
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: allocating str_idx, sizek=%d, k_tag=%p, k_str=%p\n",
        p->sizek, (void*)p->k_tag, (void*)p->k_str);
#endif
    int *str_idx = luac_alloc(sizeof(int) * p->sizek);
    int str_count = 0;
    for (int i = 0; i < p->sizek; i++) {
        int tag = p->k_tag[i];
        if ((tag == LUA_TSHRSTR || tag == LUA_TLNGSTR) && p->k_str[i]) {
            str_idx[str_count++] = i;
        }
    }
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: str_count=%d after collection\n", str_count);
#endif
    if (str_count < 2) { free(str_idx); return 0; }

    /* build blob and offset map */
    HideInfo *info = luac_alloc(sizeof(HideInfo) * p->sizek);
    memset(info, 0, sizeof(HideInfo) * p->sizek);
    size_t blob_len = 0;
    for (int i = 0; i < str_count; i++) blob_len += (size_t)p->k_str_len[str_idx[i]];
    char *blob = luac_alloc(blob_len + 1);
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: info=0x%x blob=0x%x blob_len=%u sizek=%d\n",
        (unsigned)(size_t)info, (unsigned)(size_t)blob, (unsigned)blob_len, p->sizek);
#endif
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
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: blob_len=%zu, adding constants\n", blob_len);
#endif

    /* add blob constant */
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: adding blob constant, len=%zu\n", blob_len);
    {
        void *t = malloc(1024);
        fprintf(stderr, "const_hide: heap probe malloc(1024)=%p\n", t);
        if (t) free(t);
    }
#endif
    int blob_kidx = obf_add_k_string(p, blob, blob_len);
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: blob_kidx=%d, freeing blob\n", blob_kidx);
#endif
    free(blob);
    p->k_str_len[blob_kidx] = -(int)blob_len;  /* mark as const_hide blob */

    /* add "string" and "sub" constants for inline call */
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: adding string/sub constants\n");
#endif
    int k_string = obf_add_k_string(p, "string", 6);
    int k_sub = obf_add_k_string(p, "sub", 3);

    /* add offset/endpos number constants */
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: adding %d offset/endpos number constants\n", str_count);
#endif
    for (int i = 0; i < str_count; i++) {
        int idx = str_idx[i];
        info[idx].off_kidx = obf_add_k_number(p, (double)info[idx].offset);
        info[idx].endp_kidx = obf_add_k_number(p, (double)info[idx].endpos);
    }
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: number constants done, sizek=%d\n", p->sizek);
#endif

    /* set original string constants to nil */
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: freeing %d original strings\n", str_count);
#endif
    for (int i = 0; i < str_count; i++) {
        int idx = str_idx[i];
        free(p->k_str[idx]);
        p->k_str[idx] = NULL;
        p->k_str_len[idx] = 0;
        p->k_tag[idx] = LUA_TNIL;
    }
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: original strings freed\n");
#endif
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: original strings nil'd, register allocation\n");
#endif

    /* register allocation for inline string.sub call (base_reg computed early) */
    int ENV_REG = base_reg;
    int STR_REG = base_reg + 1;
    int SUB_REG = base_reg + 2;
    /* TMP/KEY/VAL must sit beyond sub_r+4 (base_reg+6): emit_sub_call
       uses base_reg+6 as its own temporary (LOADK sub_r+4), so aliasing
       TMP_REG with it would clobber a GETUPVAL-loaded upvalue in the
       GETTABUP/SETTABUP rewrites. */
    int TMP_REG = base_reg + 7;
    int KEY_REG = base_reg + 8;
    int VAL_REG = base_reg + 9;
#if defined(CONST_HIDE_DEBUG)
    fprintf(stderr, "const_hide: base=%d env=%d str=%d sub=%d tmp=%d key=%d val=%d\n", base_reg, ENV_REG, STR_REG, SUB_REG, TMP_REG, KEY_REG, VAL_REG);
#endif
    obf_ensure_stack(p, VAL_REG + 1);

    /* First pass: build new code, track insertions */
    int *insert_pos = luac_alloc(sizeof(int) * p->sizecode);
    int *insert_len = luac_alloc(sizeof(int) * p->sizecode);
    memset(insert_pos, 0, sizeof(int) * p->sizecode);
    memset(insert_len, 0, sizeof(int) * p->sizecode);

    /* each instruction can expand to up to 22 instructions (SETTABUP with both key+val hidden: 2*10+2=22) */
    int max_new = p->sizecode * 25 + 64;
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
    /* heap-allocated to avoid WASM stack overflow (64KB default stack) */
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

    int count = 0;
    for (int i = 0; i < list_count; i++) {
#if defined(CONST_HIDE_DEBUG)
        fprintf(stderr, "const_hide: proto %d/%d sizek=%d sizecode=%d upvals=%d\n",
            i, list_count, list[i]->sizek, list[i]->sizecode, list[i]->sizeupvalues);
#endif
        count += process_function(L, list[i]);
    }
    free(list);
    free(stk);
    lua_pushinteger(L, count);
    return 1;
}
