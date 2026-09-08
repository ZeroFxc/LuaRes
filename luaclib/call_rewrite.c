/*
** call_rewrite.c - 参数/返回值混淆
**
** 参数混淆：把 f(a,b) 改成 f({a,b})，函数内部从表解包。
**   只处理 CLOSURE Rf,Bx 后紧跟 CALL Rf 的直接调用模式。
**   被调用 proto: numparams 改为 1，函数开头插入表解包代码。
**   调用点: 参数打包成表，CALL B 改为 2。
**
** 多返回值混淆：RETURN 多返回值前先打包到表再解包回寄存器。
**   语义不变，增加表操作混淆。
*/
#include <stdlib.h>
#include <string.h>
#include "obf_util.h"

#define CALL_REWRITE_DEBUG 0

static int get_or_add_int(luac_Proto *p, long long val) {
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == 19 && p->k_num[i] == (double)val) return i;
    }
    obf_add_k_integer(p, val);
    return p->sizek - 1;
}

static void insert_at(luac_Proto *p, int pos, unsigned int *ins, int n) {
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + n));
    memmove(&p->code[pos + n], &p->code[pos], sizeof(unsigned int) * (p->sizecode - pos));
    memcpy(&p->code[pos], ins, sizeof(unsigned int) * n);
    p->sizecode += n;
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, n);
}

/* 修改被调用 proto：numparams 改为 1，开头插入表解包代码 */
static int rewrite_target_proto(luac_Proto *target) {
    if (target->is_vararg) return 0;
    int np = target->numparams;
    if (np <= 1) return 0;  /* 0或1个参数不需要打包 */
    if (!target->code || target->sizecode < 1) return 0;

    /* 扩展 1 个临时寄存器 */
    int old_max = target->maxstacksize;
    if (old_max + 1 > 250) return 0;
    int Rt = old_max;
    obf_ensure_stack(target, old_max + 1);

    /* 确保常量池有 1..np */
    int kidx[256];
    for (int i = 0; i < np && i < 256; i++)
        kidx[i] = get_or_add_int(target, (long long)(i + 1));

    /* 解包代码：MOVE Rt,R0; GETTABLE R0,Rt,1; GETTABLE R1,Rt,2; ... */
    int n = 1 + np;  /* MOVE + np 条 GETTABLE */
    unsigned int *seq = malloc(sizeof(unsigned int) * n);
    seq[0] = LUAC_ABC(LUAC_OP_MOVE, Rt, 0, 0);  /* Rt = R0 (表) */
    for (int i = 0; i < np; i++) {
        seq[1 + i] = LUAC_ABC(LUAC_OP_GETTABLE, i, Rt, kidx[i] + LUAC_BITRK);
    }

    insert_at(target, 0, seq, n);
    free(seq);

    target->numparams = 1;

#if CALL_REWRITE_DEBUG
    fprintf(stderr, "[call_rewrite] target proto: np=%d->1, inserted %d ins\n", np, n);
#endif
    return 1;
}

/* 在调用点打包参数 */
static int rewrite_call_site(luac_Proto *p, int closure_pos, int call_pos) {
    int Rf = (p->code[closure_pos] >> 6) & 0xFF;
    int call_B = (p->code[call_pos] >> 23) & 0x1FF;
    int nargs = call_B - 1;
    if (nargs <= 1) return 0;  /* 0或1个参数不需要打包 */

    /* 扩展临时寄存器 */
    int old_max = p->maxstacksize;
    if (old_max + 1 > 250) return 0;
    int Rt = old_max;
    obf_ensure_stack(p, old_max + 1);

    /* 确保常量池有 1..nargs */
    int kidx[256];
    for (int i = 0; i < nargs && i < 256; i++)
        kidx[i] = get_or_add_int(p, (long long)(i + 1));

    /* 打包代码：NEWTABLE Rt; SETTABLE Rt,1,R(f+1); ...; MOVE R(f+1),Rt */
    int n = 1 + nargs + 1;  /* NEWTABLE + nargs SETTABLE + MOVE */
    unsigned int *seq = malloc(sizeof(unsigned int) * n);
    seq[0] = LUAC_ABC(LUAC_OP_NEWTABLE, Rt, 0, 0);
    for (int i = 0; i < nargs; i++) {
        /* SETTABLE Rt, key(i+1), R(f+1+i) */
        seq[1 + i] = LUAC_ABC(LUAC_OP_SETTABLE, Rt, kidx[i] + LUAC_BITRK, Rf + 1 + i);
    }
    seq[1 + nargs] = LUAC_ABC(LUAC_OP_MOVE, Rf + 1, Rt, 0);  /* R(f+1) = 表 */

    /* 在 CALL 之前插入打包代码 */
    insert_at(p, call_pos, seq, n);
    free(seq);

    /* 修改 CALL 的 B：从 nargs+1 改为 2（1个表参数） */
    int new_call_pos = call_pos + n;
    int op = p->code[new_call_pos] & 0x3F;
    int A = (p->code[new_call_pos] >> 6) & 0xFF;
    int C = (p->code[new_call_pos] >> 14) & 0x1FF;
    p->code[new_call_pos] = LUAC_ABC(op, A, 2, C);  /* B=2 */

#if CALL_REWRITE_DEBUG
    fprintf(stderr, "[call_rewrite] call site: Rf=%d nargs=%d, inserted %d ins at %d\n", Rf, nargs, n, call_pos);
#endif
    return 1;
}

/* 查找 CLOSURE Rf,Bx 后紧跟 CALL Rf 的模式（中间只能有 MOVE） */
static int find_closure_call(luac_Proto *p, int start, int *out_closure, int *out_call) {
    for (int i = start; i < p->sizecode - 1; i++) {
        if ((p->code[i] & 0x3F) != LUAC_OP_CLOSURE) continue;
        int Rf = (p->code[i] >> 6) & 0xFF;
        int Bx = (p->code[i] >> 14) & 0x3FFFF;
        if (Bx >= p->sizep) continue;

        int j = i + 1;
        while (j < p->sizecode) {
            int jop = p->code[j] & 0x3F;
            if (jop == LUAC_OP_MOVE) { j++; continue; }
            if (jop == LUAC_OP_CALL && ((p->code[j] >> 6) & 0xFF) == Rf) {
                *out_closure = i;
                *out_call = j;
                return 1;
            }
            break;
        }
    }
    return 0;
}

static int rewrite_params_in_proto(luac_Proto *p) {
    if (!p->code || p->sizecode < 2) return 0;
    int changed = 0;
    int pos = 0;
    int cpos, callpos;
    while (find_closure_call(p, pos, &cpos, &callpos)) {
        int Bx = (p->code[cpos] >> 14) & 0x3FFFF;
        luac_Proto *target = p->p[Bx];
        int call_B = (p->code[callpos] >> 23) & 0x1FF;
        int nargs = call_B - 1;

        /* 只处理参数个数匹配的直接调用 */
        if (!target->is_vararg && target->numparams == nargs && nargs > 1) {
            if (rewrite_target_proto(target)) {
                if (rewrite_call_site(p, cpos, callpos)) {
                    changed++;
                    /* 插入后位置已变，从 callpos + 打包长度 之后继续找 */
                    pos = callpos + 1 + nargs + 1 + 1;  /* 跳过本次处理的区域 */
                    continue;
                }
            }
        }
        pos = callpos + 1;
    }
    return changed;
}

/* 多返回值内部打包解包：RETURN A B (B>2) 前插入表打包+解包 */
static int rewrite_returns_in_proto(luac_Proto *p) {
    if (!p->code || p->sizecode < 1) return 0;

    int old_max = p->maxstacksize;
    if (old_max + 1 > 250) return 0;
    int Rt = old_max;
    obf_ensure_stack(p, old_max + 1);

    int changed = 0;
    int i = 0;
    while (i < p->sizecode) {
        if ((p->code[i] & 0x3F) == LUAC_OP_RETURN) {
            int A = (p->code[i] >> 6) & 0xFF;
            int B = (p->code[i] >> 23) & 0x1FF;
            if (B > 2) {  /* 返回 B-1 个值 (>=2) */
                int nret = B - 1;
                if (nret > 20) { i++; continue; }  /* 太多返回值跳过 */

                int kidx[32];
                for (int k = 0; k < nret; k++)
                    kidx[k] = get_or_add_int(p, (long long)(k + 1));

                /* NEWTABLE Rt; SETTABLE Rt,k,R(A+k); GETTABLE R(A+k),Rt,k */
                int n = 1 + nret * 2;
                unsigned int *seq = malloc(sizeof(unsigned int) * n);
                seq[0] = LUAC_ABC(LUAC_OP_NEWTABLE, Rt, 0, 0);
                for (int k = 0; k < nret; k++) {
                    seq[1 + k] = LUAC_ABC(LUAC_OP_SETTABLE, Rt, kidx[k] + LUAC_BITRK, A + k);
                    seq[1 + nret + k] = LUAC_ABC(LUAC_OP_GETTABLE, A + k, Rt, kidx[k] + LUAC_BITRK);
                }
                insert_at(p, i, seq, n);
                free(seq);
                changed++;
                i += n + 1;  /* 跳过 RETURN */
                continue;
            }
        }
        i++;
    }
    return changed;
}

int call_rewrite_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int n = 0;
    /* 参数混淆：递归处理所有 proto（先处理子 proto，再处理父 proto） */
    if (p->p) for (int i = 0; i < p->sizep; i++)
        n += rewrite_params_in_proto(p->p[i]);
    n += rewrite_params_in_proto(p);

    /* 多返回值混淆 */
    n += rewrite_returns_in_proto(p);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        n += rewrite_returns_in_proto(p->p[i]);

    lua_pushinteger(L, n);
    return 1;
}
