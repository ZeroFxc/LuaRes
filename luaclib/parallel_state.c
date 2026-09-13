/* parallel_state.c - 并行状态机
 *
 * 把 flatten 后的单个状态机拆成两个互相尾调用的 dispatch（A 和 B）。
 * A 执行完一个 block 后 TAILCALL B，B 执行完后 TAILCALL A，交替执行。
 * 两者共享同一个 state upvalue，业务逻辑在两个函数中各有一份副本。
 *
 * 结构：
 *   父函数: LOADK state + CLOSURE A + MOVE A_ref + CLOSURE B + MOVE B_ref + TAILCALL A
 *   dispatch_A: dispatcher + blocks(末尾 SETUPVAL state + GETUPVAL B_ref + TAILCALL B)
 *   dispatch_B: dispatcher + blocks(末尾 SETUPVAL state + GETUPVAL A_ref + TAILCALL A)
 *
 * 跳脱点：控制流在两个函数之间交替，CFG 变成二维调用图，每个 block 有两份副本。
 */
#include "obf_util.h"
#include <string.h>

#ifndef PARALLEL_DEBUG
#define PARALLEL_DEBUG 0
#endif
#if PARALLEL_DEBUG
#define PDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define PDBG(...)
#endif

/* A cross-closure TAILCALL is not equivalent to an in-frame JMP: Lua closes
** open upvalues (luaF_close) and rebuilds the call frame on every TAILCALL.
** If one local of this function is captured (instack) by two or more inner
** CLOSUREs, they must share the SAME open upvalue object. A switch that lands
** between those CLOSUREs closes it early, so the later closure binds a fresh
** upvalue and the shared variable splits (counter reads back its initial value).
** Such a proto cannot be rewritten across closures; leave its flat JMP machine. */
static int has_shared_captured_local(luac_Proto *p) {
    int cap[256] = {0};
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) != LUAC_OP_CLOSURE) continue;
        int bx = (p->code[i] >> 14) & 0x3FFFF;
        if (bx < 0 || bx >= p->sizep || !p->p) continue;
        luac_Proto *sub = p->p[bx];
        if (!sub) continue;
        for (int u = 0; u < sub->sizeupvalues; u++) {
            if (sub->upval_instack && sub->upval_instack[u]) {
                int r = sub->upval_idx ? sub->upval_idx[u] : 0;
                if (r >= 0 && r < 256) { cap[r]++; if (cap[r] >= 2) return 1; }
            }
        }
    }
    return 0;
}

static int find_state_reg(luac_Proto *p, int disp_start) {
    int eq_counts[256] = {0};
    int loadk_at_target[256] = {0};
    int n = p->sizecode;
    for (int i = disp_start; i < n; i++) {
        int op = p->code[i] & 0x3F;
        int a = (p->code[i] >> 6) & 0xFF;
        if (op == LUAC_OP_EQ) {
            int b = (p->code[i] >> 23) & 0x1FF;
            if (b < 256) eq_counts[b]++;
        }
        if (op == LUAC_OP_LOADK && i + 1 < n) {
            int nop = p->code[i+1] & 0x3F;
            if (nop == LUAC_OP_JMP && a < 256) loadk_at_target[a]++;
        }
    }
    int best = -1, best_score = 0;
    for (int r = 0; r < 256; r++) {
        if (eq_counts[r] >= 2 && loadk_at_target[r] >= 2) {
            if (eq_counts[r] > best_score) { best_score = eq_counts[r]; best = r; }
        }
    }
    return best;
}

static int find_disp_start(luac_Proto *p) {
    int n = p->sizecode;
    if (n < 4) return -1;
    if ((p->code[0] & 0x3F) == LUAC_OP_LOADK) {
        for (int i = 1; i < n - 1; i++) {
            if ((p->code[i] & 0x3F) == LUAC_OP_EQ &&
                (p->code[i+1] & 0x3F) == LUAC_OP_JMP) return i;
        }
    }
    for (int i = 0; i < n - 1; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_EQ &&
            (p->code[i+1] & 0x3F) == LUAC_OP_JMP) return i;
    }
    return -1;
}

/* 检测 state 是否在 upvalue 中（U 模式或 T 模式） */
static int detect_state_upval(luac_Proto *p, int *state_upval, int *state_tmp) {
    int getup_counts[256] = {0};
    int setup_counts[256] = {0};
    int getup_reg[256] = {0};
    int setup_reg[256] = {0};
    int n = p->sizecode;
    for (int i = 0; i < n; i++) {
        int op = p->code[i] & 0x3F;
        int a = (p->code[i] >> 6) & 0xFF;
        int b = (p->code[i] >> 23) & 0x1FF;
        if (op == LUAC_OP_GETUPVAL && b < 256) {
            getup_counts[b]++;
            getup_reg[b] = a;
        }
        if (op == LUAC_OP_SETUPVAL && b < 256) {
            setup_counts[b]++;
            setup_reg[b] = a;
        }
    }
    for (int u = 0; u < p->sizeupvalues; u++) {
        if (getup_counts[u] >= 2 && setup_counts[u] >= 2 && getup_reg[u] == setup_reg[u]) {
            *state_upval = u;
            *state_tmp = getup_reg[u];
            return 1;
        }
    }
    return 0;
}

/* 检测是否已经是 parallel 模式（有两个 dispatch 互相 TAILCALL） */
static int is_parallel_mode(luac_Proto *p) {
    int closure_count = 0;
    int has_tailcall = 0;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_CLOSURE) closure_count++;
        if (op == LUAC_OP_TAILCALL) has_tailcall = 1;
    }
    return closure_count >= 2 && has_tailcall;
}

/* 复制常量池 */
static void copy_constants(luac_Proto *dst, luac_Proto *src) {
    dst->sizek = src->sizek;
    dst->k_tag = (int *)malloc(sizeof(int) * dst->sizek);
    dst->k_str = (char **)malloc(sizeof(char *) * dst->sizek);
    dst->k_str_len = (int *)malloc(sizeof(int) * dst->sizek);
    dst->k_num = (double *)malloc(sizeof(double) * dst->sizek);
    dst->k_int = (long long *)malloc(sizeof(long long) * dst->sizek);
    dst->k_bool = (int *)malloc(sizeof(int) * dst->sizek);
    memset(dst->k_str, 0, sizeof(char *) * dst->sizek);
    for (int i = 0; i < dst->sizek; i++) {
        dst->k_tag[i] = src->k_tag[i];
        dst->k_num[i] = src->k_num[i];
        dst->k_int[i] = src->k_int[i];
        dst->k_bool[i] = src->k_bool[i];
        if (src->k_str[i]) {
            dst->k_str[i] = (char *)malloc(src->k_str_len[i] + 1);
            memcpy(dst->k_str[i], src->k_str[i], src->k_str_len[i]);
            dst->k_str[i][src->k_str_len[i]] = 0;
            dst->k_str_len[i] = src->k_str_len[i];
        }
    }
}

/* 构建一个 dispatch 子 proto 的代码
 * partner_upval: 伙伴函数在 upvalue 中的索引
 */
static luac_Proto *build_dispatch(luac_Proto *p, int state_reg, int disp_start,
                                   int init_kidx, int partner_upval) {
    int n = p->sizecode;
    luac_Proto *d = (luac_Proto *)calloc(1, sizeof(luac_Proto));
    d->code_tbl = LUA_NOREF; d->k_tbl = LUA_NOREF; d->p_tbl = LUA_NOREF;
    d->lineinfo_tbl = LUA_NOREF; d->locvars_tbl = LUA_NOREF; d->upvalues_tbl = LUA_NOREF;

    copy_constants(d, p);

    /* 复制子 proto 列表（共享指针） */
    d->sizep = p->sizep;
    if (p->sizep > 0) {
        d->p = (luac_Proto **)malloc(sizeof(luac_Proto *) * p->sizep);
        memcpy(d->p, p->p, sizeof(luac_Proto *) * p->sizep);
    }

    int tmp = p->maxstacksize;
    int tmp2 = p->maxstacksize + 1;
    int tmp3 = p->maxstacksize + 2;
    d->maxstacksize = p->maxstacksize + 2 + p->numparams + (p->is_vararg ? 1 : 0);

    int state_upval = p->sizeupvalues;

    /* a state LOADK+JMP pair expands to LOADK+SETUPVAL+GETUPVAL+numparams
     * MOVEs+TAILCALL, so size for the worst case, not a fixed n*3 */
    int cap = n * (p->numparams + 6) + 16;
    unsigned int *nc = (unsigned int *)malloc(sizeof(unsigned int) * cap);
    int ni = 0;
    int *pos_map = (int *)calloc(n + 1, sizeof(int));
    int *rev_map = (int *)malloc(sizeof(int) * cap);
    for (int i = 0; i < cap; i++) rev_map[i] = -1;

    pos_map[0] = 0;
    for (int i = 1; i < n; i++) {
        pos_map[i] = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;

        /* Binary-search dispatcher compares state with EQ (match) and LT
        ** (descent); once state moves into the upvalue below, both must read it
        ** via GETUPVAL or LT reads the vacated state register (nil). */
        if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) {
            int b = (ins >> 23) & 0x1FF;
            if (b == state_reg) {
                nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp, state_upval, 0);
                rev_map[ni] = -1;
                ni++;
                ins = (ins & ~(0x1FFu << 23)) | ((unsigned)tmp << 23);
            }
        }

        if (op == LUAC_OP_LOADK && a == state_reg && i + 1 < n &&
            (p->code[i+1] & 0x3F) == LUAC_OP_JMP) {
            int kidx = (ins >> 14) & 0x3FFFF;
            nc[ni] = LUAC_ABx(LUAC_OP_LOADK, tmp, kidx);
            rev_map[ni] = i;
            ni++;
            nc[ni] = LUAC_ABC(LUAC_OP_SETUPVAL, tmp, state_upval, 0);
            rev_map[ni] = -1;
            ni++;
            nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp2, partner_upval, 0);
            rev_map[ni] = -1;
            ni++;
            for (int j = 0; j < p->numparams; j++) {
                nc[ni] = LUAC_ABC(LUAC_OP_MOVE, tmp3 + j, j, 0);
                rev_map[ni] = -1;
                ni++;
            }
            if (p->is_vararg) {
                nc[ni] = LUAC_ABC(LUAC_OP_VARARG, tmp3 + p->numparams, 0, 0);
                rev_map[ni] = -1; ni++;
                nc[ni] = LUAC_ABC(LUAC_OP_TAILCALL, tmp2, 0, 0);
            } else {
                nc[ni] = LUAC_ABC(LUAC_OP_TAILCALL, tmp2, p->numparams + 1, 0);
            }
            rev_map[ni] = -1;
            ni++;
            pos_map[i + 1] = ni; /* consumed successor JMP: keep mapping dense */
            i++;
            continue;
        }

        nc[ni] = ins;
        rev_map[ni] = i;
        ni++;
    }
    pos_map[n] = ni;

    d->code = nc;
    d->sizecode = ni;

    /* 修正剩余 JMP */
    for (int i = 0; i < ni; i++) {
        int op = d->code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            int old_i = rev_map[i];
            if (old_i < 0) continue;
            int sbx = ((d->code[i] >> 14) & 0x3FFFF) - 131071;
            int old_target = old_i + 1 + sbx;
            if (old_target < 0 || old_target > n) continue;
            int new_target = pos_map[old_target];
            int new_sbx = new_target - i - 1;
            d->code[i] = (d->code[i] & 0x3FFF) | ((unsigned)(new_sbx + 131071) << 14);
        }
    }

    free(pos_map);
    free(rev_map);

    d->numparams = p->numparams;
    d->is_vararg = p->is_vararg;
    d->sizeupvalues = p->sizeupvalues + 2; /* _ENV..., state, partner */
    d->upval_instack = (unsigned char *)malloc(d->sizeupvalues);
    d->upval_idx = (unsigned char *)malloc(d->sizeupvalues);
    d->upval_name = (char **)calloc(d->sizeupvalues, sizeof(char *));
    d->upval_name_len = (int *)calloc(d->sizeupvalues, sizeof(int));
    d->lineinfo = NULL;
    d->sizelineinfo = 0;
    d->sizelocvars = 0;
    d->source = p->source ? strdup(p->source) : NULL;
    d->source_len = p->source_len;

    return d;
}

/* 从 state-upvalue 模式 dispatch 创建新 dispatch（block 末尾改 TAILCALL partner）
 * 支持 U 模式（SETUPVAL+JMP）和 T 模式（SETUPVAL+GETUPVAL self+TAILCALL）
 */
static luac_Proto *build_dispatch_from_state_upval(luac_Proto *p, int state_upval, int state_tmp,
                                                    int partner_upval) {
    int n = p->sizecode;
    luac_Proto *d = (luac_Proto *)calloc(1, sizeof(luac_Proto));
    d->code_tbl = LUA_NOREF; d->k_tbl = LUA_NOREF; d->p_tbl = LUA_NOREF;
    d->lineinfo_tbl = LUA_NOREF; d->locvars_tbl = LUA_NOREF; d->upvalues_tbl = LUA_NOREF;

    copy_constants(d, p);

    d->sizep = p->sizep;
    if (p->sizep > 0) {
        d->p = (luac_Proto **)malloc(sizeof(luac_Proto *) * p->sizep);
        memcpy(d->p, p->p, sizeof(luac_Proto *) * p->sizep);
    }

    int tmp2 = p->maxstacksize;
    int tmp3 = p->maxstacksize + 1;
    d->maxstacksize = p->maxstacksize + 1 + p->numparams + (p->is_vararg ? 1 : 0);

    /* U/T transition pair expands to SETUPVAL+GETUPVAL+numparams MOVEs+
     * TAILCALL; size for worst case rather than fixed n*2 */
    int cap = n * (p->numparams + 6) + 16;
    unsigned int *nc = (unsigned int *)malloc(sizeof(unsigned int) * cap);
    int ni = 0;
    int *pos_map = (int *)calloc(n + 1, sizeof(int));
    int *rev_map = (int *)malloc(sizeof(int) * cap);
    for (int i = 0; i < cap; i++) rev_map[i] = -1;

    for (int i = 0; i < n; i++) {
        pos_map[i] = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;

        /* U 模式：SETUPVAL state_tmp, state_upval + JMP(回dispatcher, sbx<0) → TAILCALL partner */
        if (op == LUAC_OP_SETUPVAL && a == state_tmp &&
            ((ins >> 23) & 0x1FF) == state_upval &&
            i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_JMP) {
            int jmp_sbx = ((p->code[i+1] >> 14) & 0x3FFFF) - 131071;
            if (jmp_sbx < 0) {
                nc[ni] = ins; rev_map[ni] = i; ni++; /* SETUPVAL 保留 */
                nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp2, partner_upval, 0);
                rev_map[ni] = -1; ni++;
                for (int j = 0; j < p->numparams; j++) {
                    nc[ni] = LUAC_ABC(LUAC_OP_MOVE, tmp3 + j, j, 0);
                    rev_map[ni] = -1; ni++;
                }
                if (p->is_vararg) {
                    nc[ni] = LUAC_ABC(LUAC_OP_VARARG, tmp3 + p->numparams, 0, 0);
                    rev_map[ni] = -1; ni++;
                    nc[ni] = LUAC_ABC(LUAC_OP_TAILCALL, tmp2, 0, 0);
                } else {
                    nc[ni] = LUAC_ABC(LUAC_OP_TAILCALL, tmp2, p->numparams + 1, 0);
                }
                rev_map[ni] = -1; ni++;
                pos_map[i + 1] = ni; /* consumed successor JMP: keep mapping dense */
                    i++; /* 跳过 JMP */
                continue;
            }
        }

        /* T 模式：SETUPVAL + GETUPVAL self + [MOVE参数...] + TAILCALL self → 把 self 改成 partner */
        if (op == LUAC_OP_SETUPVAL && a == state_tmp &&
            ((ins >> 23) & 0x1FF) == state_upval &&
            i + 1 < n &&
            (p->code[i+1] & 0x3F) == LUAC_OP_GETUPVAL) {
            int getupval_a = (p->code[i+1] >> 6) & 0xFF;
            /* 从 i+2 开始跳过参数 MOVE，找 TAILCALL */
            int j = i + 2;
            while (j < n && (p->code[j] & 0x3F) == LUAC_OP_MOVE) j++;
            if (j < n && (p->code[j] & 0x3F) == LUAC_OP_TAILCALL) {
                int tailcall_a = (p->code[j] >> 6) & 0xFF;
                if (tailcall_a == getupval_a) {
                /* SETUPVAL 保留 */
                nc[ni] = ins; rev_map[ni] = i; ni++;
                /* GETUPVAL tmp2, partner_upval（替换 self） */
                nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp2, partner_upval, 0);
                rev_map[ni] = -1; ni++;
                /* j 已指向 TAILCALL，跳过它 */
                j++;
                /* 写参数 MOVE + TAILCALL */
                for (int k = 0; k < p->numparams; k++) {
                    nc[ni] = LUAC_ABC(LUAC_OP_MOVE, tmp3 + k, k, 0);
                    rev_map[ni] = -1; ni++;
                }
                if (p->is_vararg) {
                    nc[ni] = LUAC_ABC(LUAC_OP_VARARG, tmp3 + p->numparams, 0, 0);
                    rev_map[ni] = -1; ni++;
                    nc[ni] = LUAC_ABC(LUAC_OP_TAILCALL, tmp2, 0, 0);
                } else {
                    nc[ni] = LUAC_ABC(LUAC_OP_TAILCALL, tmp2, p->numparams + 1, 0);
                }
                rev_map[ni] = -1; ni++;
                i = j - 1; /* 跳过已处理的指令 */
                continue;
            }
            }
        }

        nc[ni] = ins; rev_map[ni] = i; ni++;
    }
    pos_map[n] = ni;

    d->code = nc; d->sizecode = ni;

    /* 修正剩余 JMP */
    for (int i = 0; i < ni; i++) {
        int op = d->code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            int old_i = rev_map[i];
            if (old_i < 0) continue;
            int sbx = ((d->code[i] >> 14) & 0x3FFFF) - 131071;
            int old_target = old_i + 1 + sbx;
            if (old_target < 0 || old_target > n) continue;
            int new_target = pos_map[old_target];
            int new_sbx = new_target - i - 1;
            d->code[i] = (d->code[i] & 0x3FFF) | ((unsigned)(new_sbx + 131071) << 14);
        }
    }
    free(pos_map); free(rev_map);

    d->numparams = p->numparams;
    d->is_vararg = p->is_vararg;
    /* 复制原 upvalue，添加 partner */
    int old_sizeup = p->sizeupvalues;
    d->sizeupvalues = old_sizeup + 1;
    d->upval_instack = (unsigned char *)malloc(d->sizeupvalues);
    d->upval_idx = (unsigned char *)malloc(d->sizeupvalues);
    d->upval_name = (char **)calloc(d->sizeupvalues, sizeof(char *));
    d->upval_name_len = (int *)calloc(d->sizeupvalues, sizeof(int));
    memcpy(d->upval_instack, p->upval_instack, old_sizeup);
    memcpy(d->upval_idx, p->upval_idx, old_sizeup);
    for (int i = 0; i < old_sizeup; i++) {
        d->upval_name[i] = p->upval_name[i] ? strdup(p->upval_name[i]) : NULL;
        d->upval_name_len[i] = p->upval_name_len[i];
    }
    d->upval_instack[partner_upval] = 1;
    d->upval_idx[partner_upval] = 0;
    d->lineinfo = NULL; d->sizelineinfo = 0; d->sizelocvars = 0;
    d->source = p->source ? strdup(p->source) : NULL;
    d->source_len = p->source_len;

    return d;
}

/* U 模式变换：把现有 dispatch 拆成两个（A/B） */
static int convert_u_mode(lua_State *L, luac_Proto *p, luac_Proto *parent, int idx_in_parent) {
    if (!parent || idx_in_parent < 0) return 0;
    if (is_parallel_mode(parent)) return 0; /* 已经是 parallel 模式 */

    int state_upval, state_tmp;
    if (!detect_state_upval(p, &state_upval, &state_tmp)) return 0;

    PDBG("[parallel-UT] state_upval=%d state_tmp=%d sizeupval=%d\n", state_upval, state_tmp, p->sizeupvalues);

    int partner_upval = p->sizeupvalues;

    /* 根因修复（移动语义时序）：luac_push_proto 是移动语义——proto 转 userdata 后
       原裸结构的 code/p/upval_instack/upval_idx 等指针全部被置 NULL。下面
       replace/add_subproto 内部会 obf_ensure_subproto_table(parent)；若 parent 的
       p_tbl 尚未建立，首次 ensure 会把 parent 的所有子 proto（包含当前 p 自身）
       移动成 userdata 并掏空旧裸结构，随后再用旧指针访问 p->upval_instack 就会
       解引用 NULL（GEN_CRASH）。upvalue_channel 先外壳化恰好制造了"新 parent->p
       且 parent 未建表"的时序（纯 parallel 流程 parent 早已建表，故不触发）。
       因此先建好 parent 表、把本地 p 刷新为稳定 userdata 地址，再固化 p 的子节点；
       之后所有 ensure 均为 no-op，p 全程有效。 */
    obf_ensure_subproto_table(L, parent);
    if (idx_in_parent >= 0 && idx_in_parent < parent->sizep)
        p = parent->p[idx_in_parent];
    /* 固化 p 的子节点为稳定 userdata，dispatcher 浅拷贝 p->p 快照才不会被后续
       add_subproto 的所有权转移掏空（DumpCode code==NULL 崩溃根因） */
    obf_ensure_subproto_table(L, p);
    luac_Proto *disp_A = build_dispatch_from_state_upval(p, state_upval, state_tmp, partner_upval);
    luac_Proto *disp_B = build_dispatch_from_state_upval(p, state_upval, state_tmp, partner_upval);

    /* 找到父 proto 中的 CLOSURE 和 state_var */
    int disp_reg = -1, state_var = -1, closure_pos = -1;
    for (int i = 0; i < parent->sizecode; i++) {
        if ((parent->code[i] & 0x3F) == LUAC_OP_CLOSURE) {
            int bx = (parent->code[i] >> 14) & 0x3FFFF;
            if (bx == idx_in_parent) {
                disp_reg = (parent->code[i] >> 6) & 0xFF;
                closure_pos = i;
                break;
            }
        }
    }
    /* state_var 是 CLOSURE 之前的 LOADK 的 A
     * nested 模式：CLOSURE 前有两条 LOADK（state 和 outer），state 是倒数第二条 */
    int outer_var = -1;
    int is_nested = 0;
    if (closure_pos >= 2 &&
        (parent->code[closure_pos-1] & 0x3F) == LUAC_OP_LOADK &&
        (parent->code[closure_pos-2] & 0x3F) == LUAC_OP_LOADK) {
        is_nested = 1;
        state_var = (parent->code[closure_pos-2] >> 6) & 0xFF;
        outer_var = (parent->code[closure_pos-1] >> 6) & 0xFF;
    } else if (closure_pos > 0 && (parent->code[closure_pos-1] & 0x3F) == LUAC_OP_LOADK) {
        state_var = (parent->code[closure_pos-1] >> 6) & 0xFF;
    }
    if (disp_reg < 0 || state_var < 0) return 1;

    int old_numparams = parent->numparams;
    /* nested 模式下 outer_var=old_numparams+1，需要把 A_ref/B_ref/disp 寄存器往后移避免冲突 */
    int reg_offset = is_nested ? 1 : 0;
    int A_ref_var = old_numparams + 1 + reg_offset;
    int B_ref_var = old_numparams + 2 + reg_offset;
    int disp_A_reg = old_numparams + 3 + reg_offset;
    int disp_B_reg = old_numparams + 4 + reg_offset;
    int old_sizeup = p->sizeupvalues; /* dispatch 的原 upvalue 数量（不含 partner） */

    /* 字段必须在挂载前设置（push_proto 转移并置空裸结构指针字段）。
       A 替换原 dispatch 槽、B 追加；均同步 p_tbl 镜像，避免 dump 丢子 proto。 */
    disp_A->upval_idx[partner_upval] = B_ref_var;
    disp_B->upval_idx[partner_upval] = A_ref_var;
    obf_replace_subproto(L, parent, idx_in_parent, disp_A);
    int B_idx = obf_add_subproto(L, parent, disp_B);

    /* 重建父 proto 代码 */
    int upval_count = old_sizeup + 1; /* 原 upvalue + partner */
    int nlen = 11 + 2 * old_sizeup + old_numparams + (is_nested ? 1 : 0) + 4;
    unsigned int *np = (unsigned int *)malloc(sizeof(unsigned int) * nlen);
    int pni = 0;

    np[pni++] = LUAC_ABx(LUAC_OP_LOADK, state_var, (parent->code[closure_pos - (is_nested ? 2 : 1)] >> 14) & 0x3FFFF);
    if (is_nested) {
        np[pni++] = LUAC_ABx(LUAC_OP_LOADK, outer_var, (parent->code[closure_pos-1] >> 14) & 0x3FFFF);
    }
    /* CLOSURE A */
    np[pni++] = LUAC_ABx(LUAC_OP_CLOSURE, disp_A_reg, idx_in_parent);
    for (int i = 0; i < old_sizeup; i++) {
        if (p->upval_instack[i]) {
            np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_A_reg + 1 + i, p->upval_idx[i], 0);
        } else {
            np[pni++] = LUAC_ABC(LUAC_OP_GETUPVAL, disp_A_reg + 1 + i, i, 0);
        }
    }
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_A_reg + 1 + old_sizeup, B_ref_var, 0);
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, A_ref_var, disp_A_reg, 0);
    /* CLOSURE B */
    np[pni++] = LUAC_ABx(LUAC_OP_CLOSURE, disp_B_reg, B_idx);
    for (int i = 0; i < old_sizeup; i++) {
        if (p->upval_instack[i]) {
            np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_B_reg + 1 + i, p->upval_idx[i], 0);
        } else {
            np[pni++] = LUAC_ABC(LUAC_OP_GETUPVAL, disp_B_reg + 1 + i, i, 0);
        }
    }
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_B_reg + 1 + old_sizeup, A_ref_var, 0);
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, B_ref_var, disp_B_reg, 0);
    /* 传递参数（含可变参数转发） */
    for (int i = 0; i < old_numparams; i++) {
        np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_A_reg + 1 + i, i, 0);
    }
    if (parent->is_vararg) {
        np[pni++] = LUAC_ABC(LUAC_OP_VARARG, disp_A_reg + 1 + old_numparams, 0, 0);
        np[pni++] = LUAC_ABC(LUAC_OP_TAILCALL, disp_A_reg, 0, 0);
    } else {
        np[pni++] = LUAC_ABC(LUAC_OP_TAILCALL, disp_A_reg, old_numparams + 1, 0);
    }

    free(parent->code);
    parent->code = np;
    parent->sizecode = pni;
    parent->maxstacksize = (unsigned char)(disp_B_reg + upval_count + old_numparams + 1);

    PDBG("[parallel-U] done: parent=%d A=%d B=%d\n", parent->sizecode, disp_A->sizecode, disp_B->sizecode);
    return 1;
}

static int proto_has_dynamic_multret(luac_Proto *p) {
    for (int i = 0; i < p->sizecode; i++) {
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int c = (ins >> 14) & 0x1FF;
        int b = (ins >> 23) & 0x1FF;
        if ((op == LUAC_OP_CALL || op == LUAC_OP_TAILCALL) && c == 0) return 1;
        if (op == LUAC_OP_VARARG && b == 0) return 1;
    }
    return 0;
}

static int convert_proto(lua_State *L, luac_Proto *p, luac_Proto *parent, int idx_in_parent) {
    if (!p->code || p->sizecode < 4) return 0;
    if (is_parallel_mode(p)) return 0;
    if (has_shared_captured_local(p)) return 0; /* TAILCALL would split shared upvalues */
    if (proto_has_dynamic_multret(p)) return 0; /* TAILCALL resets L->top, breaks multret */

    /* 先尝试 U 模式（dispatch 子 proto，state 在 upvalue） */
    {
        int su, st;
        if (detect_state_upval(p, &su, &st) && parent) {
            /* nested 模式检测：有两个 instack=1 的 upvalue（state 和 outer）
             * WASM 不支持尾调用优化，parallel 的 A↔B TAILCALL 链会栈溢出，跳过 */
            int instack_count = 0;
            for (int i = 0; i < p->sizeupvalues; i++) {
                if (p->upval_instack[i]) instack_count++;
            }
            if (instack_count >= 2) {
                PDBG("[parallel] nested mode detected (instack=%d), skip to avoid WASM stack overflow\n", instack_count);
                return 0;
            }
            return convert_u_mode(L, p, parent, idx_in_parent);
        }
    }

    /* R 模式 */
    if (p->sizecode < 10) return 0;
    int n = p->sizecode;

    int disp_start = find_disp_start(p);
    if (disp_start < 0) return 0;
    int state_reg = find_state_reg(p, disp_start);
    if (state_reg < 0) return 0;
    if ((p->code[0] & 0x3F) != LUAC_OP_LOADK) return 0;
    int init_kidx = (p->code[0] >> 14) & 0x3FFFF;

    PDBG("[parallel] state_reg=%d disp=%d\n", state_reg, disp_start);

    /* upvalue 布局：
     * dispatch_A: [0..sizeup-1]=原upvalue, [sizeup]=state, [sizeup+1]=B_ref
     * dispatch_B: [0..sizeup-1]=原upvalue, [sizeup]=state, [sizeup+1]=A_ref
     */
    int state_upval = p->sizeupvalues;
    int partner_upval = p->sizeupvalues + 1;

    obf_ensure_subproto_table(L, p);
    luac_Proto *disp_A = build_dispatch(p, state_reg, disp_start, init_kidx, partner_upval);
    luac_Proto *disp_B = build_dispatch(p, state_reg, disp_start, init_kidx, partner_upval);

    /* 设置 A 的 upvalue 索引 */
    for (int i = 0; i < p->sizeupvalues; i++) {
        disp_A->upval_instack[i] = 0;
        disp_A->upval_idx[i] = i;
    }
    disp_A->upval_instack[state_upval] = 1;
    disp_A->upval_idx[state_upval] = 0; /* 后面设置 */
    disp_A->upval_instack[partner_upval] = 1;
    disp_A->upval_idx[partner_upval] = 0; /* 后面设置 */

    /* 设置 B 的 upvalue 索引 */
    for (int i = 0; i < p->sizeupvalues; i++) {
        disp_B->upval_instack[i] = 0;
        disp_B->upval_idx[i] = i;
    }
    disp_B->upval_instack[state_upval] = 1;
    disp_B->upval_idx[state_upval] = 0;
    disp_B->upval_instack[partner_upval] = 1;
    disp_B->upval_idx[partner_upval] = 0;

    /* 父函数寄存器布局 */
    int old_numparams = p->numparams;
    int state_var = old_numparams;
    int A_ref_var = old_numparams + 1;
    int B_ref_var = old_numparams + 2;
    int disp_A_reg = old_numparams + 3;
    int disp_B_reg = old_numparams + 4;

    /* 字段先于挂载设置，再走 add_subproto 同步 p_tbl 镜像 */
    disp_A->upval_idx[state_upval] = state_var;
    disp_A->upval_idx[partner_upval] = B_ref_var;
    disp_B->upval_idx[state_upval] = state_var;
    disp_B->upval_idx[partner_upval] = A_ref_var;
    int A_idx = obf_add_subproto(L, p, disp_A);
    int B_idx = obf_add_subproto(L, p, disp_B);

    /* 构建父函数代码 */
    int upval_count = p->sizeupvalues + 2;
    /* exact count is 11 + 2*sizeupvalues + numparams (LOADK,2*CLOSURE,
     * 2*upval loops, 6 MOVEs, param moves, TAILCALL); pad to be safe */
    int nlen = 11 + 2 * p->sizeupvalues + old_numparams + 4;
    unsigned int *np = (unsigned int *)malloc(sizeof(unsigned int) * nlen);
    int pni = 0;

    np[pni++] = LUAC_ABx(LUAC_OP_LOADK, state_var, init_kidx);
    /* CLOSURE A */
    np[pni++] = LUAC_ABx(LUAC_OP_CLOSURE, disp_A_reg, A_idx);
    /* 被消耗：A 的 upvalue */
    for (int i = 0; i < p->sizeupvalues; i++) {
        np[pni++] = LUAC_ABC(LUAC_OP_GETUPVAL, disp_A_reg + 1 + i, i, 0);
    }
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_A_reg + 1 + p->sizeupvalues, state_var, 0);
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_A_reg + 2 + p->sizeupvalues, B_ref_var, 0);
    /* 设置 A_ref 变量 */
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, A_ref_var, disp_A_reg, 0);
    /* CLOSURE B */
    np[pni++] = LUAC_ABx(LUAC_OP_CLOSURE, disp_B_reg, B_idx);
    /* 被消耗：B 的 upvalue */
    for (int i = 0; i < p->sizeupvalues; i++) {
        np[pni++] = LUAC_ABC(LUAC_OP_GETUPVAL, disp_B_reg + 1 + i, i, 0);
    }
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_B_reg + 1 + p->sizeupvalues, state_var, 0);
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_B_reg + 2 + p->sizeupvalues, A_ref_var, 0);
    /* 设置 B_ref 变量 */
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, B_ref_var, disp_B_reg, 0);
    /* 传递参数（含可变参数转发） */
    for (int i = 0; i < old_numparams; i++) {
        np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_A_reg + 1 + i, i, 0);
    }
    /* TAILCALL A */
    if (p->is_vararg) {
        np[pni++] = LUAC_ABC(LUAC_OP_VARARG, disp_A_reg + 1 + old_numparams, 0, 0);
        np[pni++] = LUAC_ABC(LUAC_OP_TAILCALL, disp_A_reg, 0, 0);
    } else {
        np[pni++] = LUAC_ABC(LUAC_OP_TAILCALL, disp_A_reg, old_numparams + 1, 0);
    }

    free(p->code);
    p->code = np;
    p->sizecode = pni;
    p->maxstacksize = (unsigned char)(disp_B_reg + upval_count + old_numparams + 1);

    PDBG("[parallel] converted: parent=%d A=%d B=%d\n", p->sizecode, disp_A->sizecode, disp_B->sizecode);
    return 1;
}

static void process_recursive(lua_State *L, luac_Proto *p, luac_Proto *parent, int idx_in_parent, int *total) {
    if (p->p) {
        /* Fix the child count BEFORE converting: a child's conversion reallocs
         * p->p and appends disp_A/disp_B; iterating the growing sizep would
         * re-enter the freshly built dispatch protos and cascade. */
        int orig_sizep = p->sizep;
        for (int i = 0; i < orig_sizep; i++)
            process_recursive(L, p->p[i], p, i, total);
    }
    *total += convert_proto(L, p, parent, idx_in_parent);
}

int parallel_state_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    luac_sync_proto(L, 1);
    obf_invalidate_all_caches(L, p);
    int total = 0;
    process_recursive(L, p, NULL, -1, &total);
    lua_pushinteger(L, total);
    return 1;
}
