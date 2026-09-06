/*
** detable_obfuscate.c - Reverse table_obfuscate
** 1. MOVE A+1,B + GETTABLE A,B,C -> SELF A,B,C
** 2. LOADK tmp,K + TABLE_OP R(tmp) -> TABLE_OP K
*/
#include "obf_util.h"

#define BITRK 0x100

static void adjust_jumps_remove(unsigned int *code, int n, int remove_pos, int cnt) {
    for (int i = 0; i < n; i++) {
        int op = code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            int sbx = (int)(code[i] >> 14) - 131071;
            if (op == LUAC_OP_JMP && sbx == 0) continue;
            int target = i + sbx + 1;
            int delta = 0;
            if (i < remove_pos && target >= remove_pos) delta = -cnt;
            else if (i >= remove_pos && target < remove_pos) delta = cnt;
            if (delta != 0) {
                int a = (code[i] >> 6) & 0xFF;
                code[i] = LUAC_AsBx(op, a, sbx + delta);
            }
        }
    }
}

static void remove_insn(luac_Proto *p, int pos) {
    adjust_jumps_remove(p->code, p->sizecode, pos + 1, 1);
    memmove(&p->code[pos], &p->code[pos+1], sizeof(unsigned int) * (p->sizecode - pos - 1));
    p->sizecode--;
}

/* liveness: is reg read before being written from start..end? */
static int is_reg_live_after(unsigned int *code, int n, int start, int reg) {
    for (int i = start; i < n; i++) {
        int op = code[i] & 0x3F;
        int a = (code[i] >> 6) & 0xFF;
        int writes_a = 1;
        if (op==8||op==10||op==30||op==31||op==32||op==33||op==34||op==36||op==37||op==38||op==44||op==43||op==45) writes_a = 0;
        int b = (code[i] >> 23) & 0x1FF;
        int c = (code[i] >> 14) & 0x1FF;
        int reads_bc = 1;
        if (op==1||op==2||op==3||op==4||op==11||op==30||op==39||op==40||op==42||op==44||op==43||op==46) reads_bc = 0;
        if (op==36||op==37||op==38) reads_bc = 0;
        if (reads_bc && b < 256 && b == reg) return 1;
        if (reads_bc && c < 256 && c == reg) return 1;
        if ((op==36||op==37) && a <= reg && reg < a + b) return 1;
        if (writes_a && a == reg) return 0;
    }
    return 0;
}

static int restore_self(luac_Proto *p) {
    int count = 0;
    for (int i = 0; i < p->sizecode - 1; ) {
        if ((p->code[i] & 0x3F) == LUAC_OP_MOVE && (p->code[i+1] & 0x3F) == LUAC_OP_GETTABLE) {
            int a1 = (p->code[i] >> 6) & 0xFF;
            int b1 = (p->code[i] >> 23) & 0x1FF;
            int a2 = (p->code[i+1] >> 6) & 0xFF;
            int b2 = (p->code[i+1] >> 23) & 0x1FF;
            int c2 = (p->code[i+1] >> 14) & 0x1FF;
            if (a1 == a2 + 1 && b1 == b2 && b1 < 256) {
                p->code[i] = LUAC_ABC(LUAC_OP_SELF, a2, b2, c2);
                remove_insn(p, i + 1);
                count++;
                continue; /* recheck current pos */
            }
        }
        i++;
    }
    return count;
}

static int restore_materialized(luac_Proto *p) {
    int count = 0;
    for (int i = 0; i < p->sizecode - 1; ) {
        if ((p->code[i] & 0x3F) == LUAC_OP_LOADK) {
            int tmp = (p->code[i] >> 6) & 0xFF;
            int key_idx = (p->code[i] >> 14) & 0x3FFFF;
            int op2 = p->code[i+1] & 0x3F;
            int reversed = 0;

            if (op2 == LUAC_OP_GETTABLE) {
                int a=(p->code[i+1]>>6)&0xFF, b=(p->code[i+1]>>23)&0x1FF, c=(p->code[i+1]>>14)&0x1FF;
                if (c==tmp && c<256 && a!=tmp && !is_reg_live_after(p->code,p->sizecode,i+2,tmp)) {
                    p->code[i] = LUAC_ABC(LUAC_OP_GETTABLE, a, b, key_idx + BITRK);
                    remove_insn(p, i+1); count++; reversed=1;
                }
            } else if (op2 == LUAC_OP_SETTABLE) {
                int a=(p->code[i+1]>>6)&0xFF, b=(p->code[i+1]>>23)&0x1FF, c=(p->code[i+1]>>14)&0x1FF;
                if (b==tmp && b<256 && a!=tmp && !is_reg_live_after(p->code,p->sizecode,i+2,tmp)) {
                    p->code[i] = LUAC_ABC(LUAC_OP_SETTABLE, a, key_idx+BITRK, c);
                    remove_insn(p, i+1); count++; reversed=1;
                } else if (c==tmp && c<256 && a!=tmp && b!=tmp && !is_reg_live_after(p->code,p->sizecode,i+2,tmp)) {
                    p->code[i] = LUAC_ABC(LUAC_OP_SETTABLE, a, b, key_idx+BITRK);
                    remove_insn(p, i+1); count++; reversed=1;
                }
            } else if (op2 == LUAC_OP_GETTABUP) {
                int a=(p->code[i+1]>>6)&0xFF, b=(p->code[i+1]>>23)&0x1FF, c=(p->code[i+1]>>14)&0x1FF;
                if (c==tmp && c<256 && a!=tmp && !is_reg_live_after(p->code,p->sizecode,i+2,tmp)) {
                    p->code[i] = LUAC_ABC(LUAC_OP_GETTABUP, a, b, key_idx+BITRK);
                    remove_insn(p, i+1); count++; reversed=1;
                }
            } else if (op2 == LUAC_OP_SETTABUP) {
                int a=(p->code[i+1]>>6)&0xFF, b=(p->code[i+1]>>23)&0x1FF, c=(p->code[i+1]>>14)&0x1FF;
                if (b==tmp && b<256 && !is_reg_live_after(p->code,p->sizecode,i+2,tmp)) {
                    p->code[i] = LUAC_ABC(LUAC_OP_SETTABUP, a, key_idx+BITRK, c);
                    remove_insn(p, i+1); count++; reversed=1;
                } else if (c==tmp && c<256 && b!=tmp && !is_reg_live_after(p->code,p->sizecode,i+2,tmp)) {
                    p->code[i] = LUAC_ABC(LUAC_OP_SETTABUP, a, b, key_idx+BITRK);
                    remove_insn(p, i+1); count++; reversed=1;
                }
            }
            if (!reversed) i++;
        } else {
            i++;
        }
    }
    return count;
}

static int clean_proto(luac_Proto *p) {
    int total = restore_self(p);
    total += restore_materialized(p);
    return total;
}

int detable_obfuscate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    int total = clean_proto(p);
    if (p->p) for (int i = 0; i < p->sizep; i++) total += clean_proto(p->p[i]);
    lua_pushinteger(L, total);
    return 1;
}
