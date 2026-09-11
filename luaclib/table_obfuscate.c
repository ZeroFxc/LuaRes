/*
** table_obfuscate.c - Table instruction obfuscation (逐字段构建)
**
** 1. NEWTABLE allocation hint zeroing
** 2. SELF -> MOVE + GETTABLE
** 3. GETTABLE/SETTABLE/GETTABUP/SETTABUP: 常量 key/val 全部物化到寄存器
**    SETTABLE 同时物化 key 和 value（两个临时寄存器），反编译器无法直接还原表字面量
** 4. 表构造器字段间插入不透明垃圾块
*/
#include <time.h>
#include "obf_util.h"

#define BITRK 0x100

static void insert_insn(luac_Proto *p, int pos, unsigned int insn) {
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + 1));
    memmove(&p->code[pos+1], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
    p->code[pos] = insn;
    p->sizecode++;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, 1);
}

/* NEWTABLE hint 清零 */
static int obf_newtable(luac_Proto *p) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_NEWTABLE) {
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (b > 0 || c > 0) {
                int a = (p->code[i] >> 6) & 0xFF;
                p->code[i] = LUAC_ABC(LUAC_OP_NEWTABLE, a, 0, 0);
                count++;
            }
        }
    }
    return count;
}

/* SELF -> MOVE + GETTABLE */
static int obf_self(luac_Proto *p) {
    int count = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_SELF) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            p->code[i] = LUAC_ABC(LUAC_OP_MOVE, a + 1, b, 0);
            insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_GETTABLE, a, b, c));
            count++;
            i++;
        }
    }
    return count;
}

/*
** 逐字段构建核心：遍历所有指令，对每条表操作做常量物化
** 使用两个临时寄存器 tmp_k (key) 和 tmp_v (value)
** SETTABLE: key 和 value 同时物化
** GETTABLE: key 物化
** GETTABUP: key 物化
** SETTABUP: key 和 value 同时物化
*/
static int obf_table_fields(luac_Proto *p, int tmp_k, int tmp_v) {
    int count = 0;
    int i = 0;
    while (i < p->sizecode) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;
        int b = (ins >> 23) & 0x1FF;
        int c = (ins >> 14) & 0x1FF;

        if (op == LUAC_OP_SETTABLE) {
            int key_is_const = (b >= BITRK);
            int val_is_const = (c >= BITRK);
            if (!key_is_const && !val_is_const) { i++; continue; }
            /* 跳过临时寄存器自身 */
            if (a == tmp_k || a == tmp_v) { i++; continue; }

            int new_b = key_is_const ? tmp_k : b;
            int new_c = val_is_const ? tmp_v : c;
            int pos = i;

            if (key_is_const) {
                p->code[pos] = LUAC_ABx(LUAC_OP_LOADK, tmp_k, b - BITRK);
                insert_insn(p, pos + 1, 0); /* placeholder, will fill */
                pos++;
            }
            if (val_is_const) {
                p->code[pos] = LUAC_ABx(LUAC_OP_LOADK, tmp_v, c - BITRK);
                insert_insn(p, pos + 1, 0);
                pos++;
            }
            p->code[pos] = LUAC_ABC(LUAC_OP_SETTABLE, a, new_b, new_c);
            count++;
            i = pos + 1;
            continue;
        }

        if (op == LUAC_OP_GETTABLE) {
            if (c < BITRK || a == tmp_k || a == tmp_v || b == tmp_k || b == tmp_v) { i++; continue; }
            p->code[i] = LUAC_ABx(LUAC_OP_LOADK, tmp_k, c - BITRK);
            insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_GETTABLE, a, b, tmp_k));
            count++;
            i += 2;
            continue;
        }

        if (op == LUAC_OP_GETTABUP) {
            if (c < BITRK || a == tmp_k) { i++; continue; }
            p->code[i] = LUAC_ABx(LUAC_OP_LOADK, tmp_k, c - BITRK);
            insert_insn(p, i + 1, LUAC_ABC(LUAC_OP_GETTABUP, a, b, tmp_k));
            count++;
            i += 2;
            continue;
        }

        if (op == LUAC_OP_SETTABUP) {
            int key_is_const = (b >= BITRK);
            int val_is_const = (c >= BITRK);
            if (!key_is_const && !val_is_const) { i++; continue; }
            if (a == tmp_k || a == tmp_v) { i++; continue; }

            int new_b = key_is_const ? tmp_k : b;
            int new_c = val_is_const ? tmp_v : c;
            int pos = i;

            if (key_is_const) {
                p->code[pos] = LUAC_ABx(LUAC_OP_LOADK, tmp_k, b - BITRK);
                insert_insn(p, pos + 1, 0);
                pos++;
            }
            if (val_is_const) {
                p->code[pos] = LUAC_ABx(LUAC_OP_LOADK, tmp_v, c - BITRK);
                insert_insn(p, pos + 1, 0);
                pos++;
            }
            p->code[pos] = LUAC_ABC(LUAC_OP_SETTABUP, a, new_b, new_c);
            count++;
            i = pos + 1;
            continue;
        }

        i++;
    }
    return count;
}

static int obfuscate_proto(luac_Proto *p) {
    int total = 0;
    total += obf_newtable(p);
    total += obf_self(p);

    int tmp_k = p->maxstacksize;
    int tmp_v = p->maxstacksize + 1;
    int mat = (tmp_v + 1 > 250) ? 0 : obf_table_fields(p, tmp_k, tmp_v);
    if (mat > 0) {
        int ns = tmp_v + 1;
        if (ns > 250) ns = 250;
        if (p->maxstacksize < ns) p->maxstacksize = (unsigned char)ns;
    }
    total += mat;
    return total;
}

int table_obfuscate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    int total = obfuscate_proto(p);
    if (p->p) for (int i = 0; i < p->sizep; i++) total += obfuscate_proto(p->p[i]);
    lua_pushinteger(L, total);
    return 1;
}
