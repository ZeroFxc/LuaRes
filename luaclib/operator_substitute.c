/*
** operator_substitute.c - 运算符等价替换
**
** ADD  -> (a&b)+(a|b)  或  a-(-b)
** SUB  -> a+(-b)
** MUL  -> ((a+b)^2 - a^2 - b^2)/2
**
** 简单运算变复杂运算链，纯 opcode 实现。
** 临时变量使用高寄存器，不干扰真实代码。
*/
#include <stdlib.h>
#include <string.h>
#include "obf_util.h"

#define OPSUB_DEBUG 0

/* 在 pos 处替换 1 条指令为 n 条新指令，修正 JMP */
static void replace_at(luac_Proto *p, int pos, unsigned int *new_ins, int n) {
    int delta = n - 1; /* 净增加指令数 */
    if (delta > 0) {
        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + delta));
        memmove(&p->code[pos + n], &p->code[pos + 1],
                sizeof(unsigned int) * (p->sizecode - pos - 1));
    } else if (delta < 0) {
        memmove(&p->code[pos + n], &p->code[pos + 1],
                sizeof(unsigned int) * (p->sizecode - pos - 1));
    }
    memcpy(&p->code[pos], new_ins, sizeof(unsigned int) * n);
    p->sizecode += delta;
    if (delta != 0)
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, delta);
}

static int inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 1 || count <= 0) return 0;
    /* B=0 instructions read to stack top — expanding maxstack injects extra values */
    for (int _si = 0; _si < p->sizecode; _si++) {
        int _op = p->code[_si] & 0x3F;
        if ((_op == 36 || _op == 37 || _op == 38 || _op == 45 || _op == 43) &&
            ((p->code[_si] >> 23) & 0x1FF) == 0) return 0;
    }
    /* 扩展 3 个临时寄存器 */
    int old_max = p->maxstacksize;
    int extra = 3;
    if (old_max + extra > 245) extra = 245 - old_max;
    if (extra < 2) return 0;
    int t0 = old_max, t1 = old_max + 1, t2 = old_max + 2;
    obf_ensure_stack(p, old_max + extra);

    /* 确保常量池有 2.0（MUL 替换用） */
    int k2 = -1;
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == 3 || p->k_tag[i] == 19) && p->k_num[i] == 2.0) { k2 = i; break; }
    }
    if (k2 < 0) { obf_add_k_number(p, 2.0); k2 = p->sizek - 1; }
    unsigned int rk2 = k2 + LUAC_BITRK;

    int changed = 0;
    int i = 0;
    while (i < p->sizecode && changed < count) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int A = (ins >> 6) & 0xFF;
        int B = (ins >> 23) & 0x1FF;
        int C = (ins >> 14) & 0x1FF;

        if (op == LUAC_OP_ADD) {
            /* 随机选两种替换 */
            if (obf_rand() % 2 == 0) {
                /* (a&b)+(a|b) : BAND t0,B,C; BOR t1,B,C; ADD A,t0,t1 */
                unsigned int seq[3] = {
                    LUAC_ABC(LUAC_OP_BAND, t0, B, C),
                    LUAC_ABC(LUAC_OP_BOR, t1, B, C),
                    LUAC_ABC(LUAC_OP_ADD, A, t0, t1)
                };
                replace_at(p, i, seq, 3);
                i += 3;
            } else {
                /* a-(-b) : if C is reg: UNM t0,C; SUB A,B,t0
                           if C is const: LOADK t0,C-256; UNM t0,t0; SUB A,B,t0 */
                if (C < 256) {
                    unsigned int seq[2] = {
                        LUAC_ABC(LUAC_OP_UNM, t0, C, 0),
                        LUAC_ABC(LUAC_OP_SUB, A, B, t0)
                    };
                    replace_at(p, i, seq, 2);
                    i += 2;
                } else {
                    unsigned int seq[3] = {
                        LUAC_ABx(LUAC_OP_LOADK, t0, C - 256),
                        LUAC_ABC(LUAC_OP_UNM, t0, t0, 0),
                        LUAC_ABC(LUAC_OP_SUB, A, B, t0)
                    };
                    replace_at(p, i, seq, 3);
                    i += 3;
                }
            }
            changed++;
            continue;
        } else if (op == LUAC_OP_SUB) {
            /* a+(-b) */
            if (C < 256) {
                unsigned int seq[2] = {
                    LUAC_ABC(LUAC_OP_UNM, t0, C, 0),
                    LUAC_ABC(LUAC_OP_ADD, A, B, t0)
                };
                replace_at(p, i, seq, 2);
                i += 2;
            } else {
                unsigned int seq[3] = {
                    LUAC_ABx(LUAC_OP_LOADK, t0, C - 256),
                    LUAC_ABC(LUAC_OP_UNM, t0, t0, 0),
                    LUAC_ABC(LUAC_OP_ADD, A, B, t0)
                };
                replace_at(p, i, seq, 3);
                i += 3;
            }
            changed++;
            continue;
        } else if (op == LUAC_OP_MUL) {
            /* ((a+b)^2 - a^2 - b^2)/2
               ADD t0,B,C; MUL t0,t0,t0; MUL t1,B,B; MUL t2,C,C;
               SUB t0,t0,t1; SUB t0,t0,t2; DIV A,t0,rk2 */
            unsigned int seq[7] = {
                LUAC_ABC(LUAC_OP_ADD, t0, B, C),
                LUAC_ABC(LUAC_OP_MUL, t0, t0, t0),
                LUAC_ABC(LUAC_OP_MUL, t1, B, B),
                LUAC_ABC(LUAC_OP_MUL, t2, C, C),
                LUAC_ABC(LUAC_OP_SUB, t0, t0, t1),
                LUAC_ABC(LUAC_OP_SUB, t0, t0, t2),
                LUAC_ABC(LUAC_OP_DIV, A, t0, rk2)
            };
            replace_at(p, i, seq, 7);
            i += 7;
            changed++;
            continue;
        }
        i++;
    }

#if OPSUB_DEBUG
    fprintf(stderr, "[opsub] changed=%d sizecode=%d\n", changed, p->sizecode);
#endif
    return changed;
}

int operator_substitute_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int count = 50;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }

    int n = inject_function(p, count);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        n += inject_function(p->p[i], count > 5 ? count / 2 : 5);

    lua_pushinteger(L, n);
    return 1;
}
