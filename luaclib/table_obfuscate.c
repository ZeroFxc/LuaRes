/*
** table_obfuscate.c - Table instruction obfuscation
** 1. NEWTABLE allocation hint zeroing
** 2. SELF -> MOVE + GETTABLE
** 3. GETTABLE/SETTABLE/GETTABUP/SETTABUP constant key/val materialization
*/
#include <time.h>
#include "obf_util.h"

#define BITRK 0x100

/* insert one instruction at pos (0-based), shift rest, adjust jumps */
static void insert_insn(luac_Proto *p, int pos, unsigned int insn) {
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + 1));
    memmove(&p->code[pos+1], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
    p->code[pos] = insn;
    p->sizecode++;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, 1);
}

static int obf_newtable(luac_Proto *p, double rate) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_NEWTABLE) {
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if ((b > 0 || c > 0) && ((double)obf_rand() / 0xFFFFFFFFu) < rate) {
                int a = (p->code[i] >> 6) & 0xFF;
                p->code[i] = LUAC_ABC(LUAC_OP_NEWTABLE, a, 0, 0);
                count++;
            }
        }
    }
    return count;
}

static int obf_self(luac_Proto *p, double rate) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_SELF && ((double)obf_rand() / 0xFFFFFFFFu) < rate) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            p->code[i] = LUAC_ABC(LUAC_OP_MOVE, a + 1, b, 0);
            insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_GETTABLE, a, b, c));
            count++;
            i++; /* skip inserted */
        }
    }
    return count;
}

static int obf_gettable_key(luac_Proto *p, double rate, int tmp) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_GETTABLE) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (c >= BITRK && a != tmp && b < 256 && ((double)obf_rand() / 0xFFFFFFFFu) < rate) {
                int key = c - BITRK;
                p->code[i] = LUAC_ABx(LUAC_OP_LOADK, tmp, key);
                insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_GETTABLE, a, b, tmp));
                count++;
                i++;
            }
        }
    }
    return count;
}

static int obf_settable_key(luac_Proto *p, double rate, int tmp) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_SETTABLE) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (b >= BITRK && a != tmp && ((double)obf_rand() / 0xFFFFFFFFu) < rate) {
                int key = b - BITRK;
                p->code[i] = LUAC_ABx(LUAC_OP_LOADK, tmp, key);
                insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_SETTABLE, a, tmp, c));
                count++;
                i++;
            }
        }
    }
    return count;
}

static int obf_settable_val(luac_Proto *p, double rate, int tmp) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_SETTABLE) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (c >= BITRK && b != tmp && a != tmp && ((double)obf_rand() / 0xFFFFFFFFu) < rate) {
                int val = c - BITRK;
                p->code[i] = LUAC_ABx(LUAC_OP_LOADK, tmp, val);
                insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_SETTABLE, a, b, tmp));
                count++;
                i++;
            }
        }
    }
    return count;
}

static int obf_gettabup_key(luac_Proto *p, double rate, int tmp) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_GETTABUP) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (c >= BITRK && a != tmp && ((double)obf_rand() / 0xFFFFFFFFu) < rate) {
                int key = c - BITRK;
                p->code[i] = LUAC_ABx(LUAC_OP_LOADK, tmp, key);
                insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_GETTABUP, a, b, tmp));
                count++;
                i++;
            }
        }
    }
    return count;
}

static int obf_settabup(luac_Proto *p, double rate, int tmp) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_SETTABUP) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            int mat_key = (b >= BITRK);
            int mat_val = (c >= BITRK && !mat_key);
            if (b >= BITRK && c >= BITRK) {
                if (obf_rand() % 2 == 0) { mat_key = 1; mat_val = 0; }
                else { mat_key = 0; mat_val = 1; }
            }
            if ((mat_key || mat_val) && ((double)obf_rand() / 0xFFFFFFFFu) < rate) {
                if (mat_key) {
                    int key = b - BITRK;
                    p->code[i] = LUAC_ABx(LUAC_OP_LOADK, tmp, key);
                    insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_SETTABUP, a, tmp, c));
                } else {
                    int val = c - BITRK;
                    p->code[i] = LUAC_ABx(LUAC_OP_LOADK, tmp, val);
                    insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_SETTABUP, a, b, tmp));
                }
                count++;
                i++;
            }
        }
    }
    return count;
}

static int obfuscate_proto(luac_Proto *p) {
    int total = 0;
    total += obf_newtable(p, 0.8);
    total += obf_self(p, 0.5);
    int tmp = p->maxstacksize;
    int mat = 0;
    mat += obf_gettable_key(p, 0.4, tmp);
    mat += obf_settable_key(p, 0.4, tmp);
    mat += obf_settable_val(p, 0.3, tmp);
    mat += obf_gettabup_key(p, 0.4, tmp);
    mat += obf_settabup(p, 0.35, tmp);
    if (mat > 0) {
        int ns = tmp + 1; if (ns > 250) ns = 250;
        if (p->maxstacksize < ns) p->maxstacksize = (unsigned char)ns;
    }
    total += mat;
    return total;
}

int table_obfuscate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    obf_srand((unsigned int)time(NULL));
    int total = obfuscate_proto(p);
    if (p->p) for (int i = 0; i < p->sizep; i++) total += obfuscate_proto(p->p[i]);
    lua_pushinteger(L, total);
    return 1;
}
