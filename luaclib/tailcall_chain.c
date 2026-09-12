/* tailcall_chain.c - 尾调用链
 *
 * 把 flatten 状态机的块间转移从 JMP 回 dispatcher 改为 TAILCALL 自身闭包。
 * 支持两种输入模式：
 *   R 模式（原始 flatten）：state 在寄存器，JMP 转移 → 创建 dispatch，state→upvalue + JMP→TAILCALL
 *   U 模式（upvalue_channel 后）：state 在 upvalue，JMP 转移 → 在现有 dispatch 上改 JMP→TAILCALL
 *
 * 效果：CFG 变成调用图，反编译器看到的是函数互相尾调用而非跳转循环。
 */
#include "obf_util.h"
#include <string.h>

#ifndef TAILCALL_DEBUG
#define TAILCALL_DEBUG 0
#endif
#if TAILCALL_DEBUG
#define TDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define TDBG(...)
#endif

/* === 识别函数 === */

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
    /* R 模式：code[0] 是 LOADK state 初始化 */
    if ((p->code[0] & 0x3F) == LUAC_OP_LOADK) {
        for (int i = 1; i < n - 1; i++) {
            if ((p->code[i] & 0x3F) == LUAC_OP_EQ &&
                (p->code[i+1] & 0x3F) == LUAC_OP_JMP) return i;
        }
    }
    /* U 模式：开头可能是 GETUPVAL，直接找 EQ+JMP */
    for (int i = 0; i < n - 1; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_EQ &&
            (p->code[i+1] & 0x3F) == LUAC_OP_JMP) return i;
    }
    return -1;
}

/* 检测 U 模式：state 在 upvalue 中 */
static int detect_u_mode(luac_Proto *p, int *state_upval, int *state_tmp) {
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

/* 检测是否已经是 T 模式（有 TAILCALL 回 dispatcher） */
static int is_t_mode(luac_Proto *p) {
    int n = p->sizecode;
    for (int i = 0; i < n; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_TAILCALL) return 1;
    }
    return 0;
}

static long long get_int_const(luac_Proto *p, int idx) {
    if (idx < 0 || idx >= p->sizek) return 0;
    if (p->k_tag[idx] == LUA_TNUMINT) return p->k_int[idx];
    if (p->k_tag[idx] == LUA_TNUMFLT) return (long long)p->k_num[idx];
    return 0;
}

/* === U 模式变换：在现有 dispatch 上改 JMP→TAILCALL === */

static int convert_u_mode(luac_Proto *p, luac_Proto *parent, int idx_in_parent) {
    if (!parent || idx_in_parent < 0) return 0; /* 需要父 proto 配合 */

    int state_upval, state_tmp;
    if (!detect_u_mode(p, &state_upval, &state_tmp)) return 0;
    if (is_t_mode(p)) return 0; /* 已经是 T 模式 */

    /* nested 模式检测：有两个 instack=1 的 upvalue（state 和 outer）
     * WASM 不支持尾调用优化，nested+TAILCALL 会栈溢出，跳过处理 */
    int instack_count = 0;
    for (int i = 0; i < p->sizeupvalues; i++) {
        if (p->upval_instack[i]) instack_count++;
    }
    if (instack_count >= 2) {
        TDBG("[tailcall-U] nested mode detected (instack=%d), skip to avoid WASM stack overflow\n", instack_count);
        return 0;
    }

    TDBG("[tailcall-U] state_upval=%d state_tmp=%d sizeupval=%d\n", state_upval, state_tmp, p->sizeupvalues);

    int self_upval = p->sizeupvalues;
    int tmp2 = p->maxstacksize;  /* 用于 GETUPVAL self */
    int tmp3 = p->maxstacksize + 1; /* 用于传递参数 */

    /* 检测 indirect 模式：开头 MOVE table_local, table_param（table 参数移到高寄存器） */
    int is_indirect = 0;
    int table_local = -1;
    int table_param = p->numparams - 1;
    if (p->numparams >= 2 && (p->code[0] & 0x3F) == LUAC_OP_MOVE) {
        int a = (p->code[0] >> 6) & 0xFF;
        int b = (p->code[0] >> 23) & 0x1FF;
        if (b == table_param && a >= p->maxstacksize - 2) {
            is_indirect = 1;
            table_local = a;
        }
    }
    TDBG("[tailcall-U] indirect=%d table_local=%d table_param=%d\n", is_indirect, table_local, table_param);

    /* 1. 添加 self upvalue 到 dispatch */
    int old_sizeup = p->sizeupvalues;
    unsigned char *old_instack = p->upval_instack;
    unsigned char *old_idx = p->upval_idx;
    char **old_name = p->upval_name;
    int *old_name_len = p->upval_name_len;

    p->sizeupvalues = old_sizeup + 1;
    p->upval_instack = (unsigned char *)malloc(p->sizeupvalues);
    p->upval_idx = (unsigned char *)malloc(p->sizeupvalues);
    p->upval_name = (char **)calloc(p->sizeupvalues, sizeof(char *));
    p->upval_name_len = (int *)calloc(p->sizeupvalues, sizeof(int));
    memcpy(p->upval_instack, old_instack, old_sizeup);
    memcpy(p->upval_idx, old_idx, old_sizeup);
    for (int i = 0; i < old_sizeup; i++) {
        p->upval_name[i] = old_name[i];
        p->upval_name_len[i] = old_name_len[i];
    }
    p->upval_instack[self_upval] = 1; /* self: 父函数局部变量 */
    p->upval_idx[self_upval] = 0;     /* 后面由父函数设置 */
    free(old_instack); free(old_idx); free(old_name); free(old_name_len);

    /* 2. 构建新代码：把 SETUPVAL + JMP(回dispatcher) 改成 SETUPVAL + GETUPVAL self + TAILCALL */
    int n = p->sizecode;
    int cap = n * 2;
    unsigned int *nc = (unsigned int *)malloc(sizeof(unsigned int) * cap);
    int *pos_map = (int *)malloc(sizeof(int) * (n + 1));
    int *rev_map = (int *)malloc(sizeof(int) * cap);
    for (int i = 0; i < cap; i++) rev_map[i] = -1;

    int ni = 0;
    for (int i = 0; i < n; i++) {
        pos_map[i] = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;

        /* SETUPVAL state_tmp, state_upval + JMP(回dispatcher, sbx<0) → TAILCALL 链 */
        if (op == LUAC_OP_SETUPVAL && a == state_tmp &&
            (ins >> 23 & 0x1FF) == state_upval &&
            i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_JMP) {
            int jmp_sbx = ((p->code[i+1] >> 14) & 0x3FFFF) - 131071;
            if (jmp_sbx < 0) { /* 回 dispatcher 的 JMP（向后跳） */
                /* SETUPVAL tmp, state_upval（保留） */
                nc[ni] = ins; rev_map[ni] = i; ni++;
                /* GETUPVAL tmp2, self_upval */
                nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp2, self_upval, 0);
                rev_map[ni] = -1; ni++;
                /* 传递所有参数 */
                for (int j = 0; j < p->numparams; j++) {
                    int src = j;
                    if (is_indirect && j == table_param) {
                        src = table_local; /* table 已移到高寄存器，避免被 _ENV 覆盖 */
                    }
                    nc[ni] = LUAC_ABC(LUAC_OP_MOVE, tmp3 + j, src, 0);
                    rev_map[ni] = -1; ni++;
                }
                /* TAILCALL tmp2, numparams+1, 0 */
                nc[ni] = LUAC_ABC(LUAC_OP_TAILCALL, tmp2, p->numparams + 1, 0);
                rev_map[ni] = -1; ni++;
                i++; /* 跳过原来的 JMP */
                continue;
            }
        }

        nc[ni] = ins;
        rev_map[ni] = i;
        ni++;
    }
    pos_map[n] = ni;

    free(p->code);
    p->code = nc;
    p->sizecode = ni;
    p->maxstacksize = (unsigned char)(tmp3 + p->numparams);

    /* 修正剩余 JMP（EQ 后的 JMP，指向 block） */
    for (int i = 0; i < ni; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            int old_i = rev_map[i];
            if (old_i < 0) continue;
            int sbx = ((p->code[i] >> 14) & 0x3FFFF) - 131071;
            int old_target = old_i + 1 + sbx;
            if (old_target < 0 || old_target > n) continue;
            int new_target = pos_map[old_target];
            int new_sbx = new_target - i - 1;
            p->code[i] = (p->code[i] & 0xFFF) | ((unsigned)(new_sbx + 131071) << 14);
        }
    }
    free(pos_map); free(rev_map);

    /* 3. 修改父 proto：添加 self upvalue 设置，CALL→TAILCALL */
    /* 父 proto 结构：LOADK state + CLOSURE disp + 被消耗upvalue(sizeup) + MOVE参数 + CALL + RETURN */
    /* 需要找到 CLOSURE 指令，确定 disp_reg */
    int disp_reg = -1;
    int closure_pos = -1;
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
    if (disp_reg < 0) return 1; /* dispatch 已改，但父 proto 没找到 CLOSURE，不应该发生 */

    p->upval_idx[self_upval] = disp_reg; /* self = dispatch 闭包自身 */

    /* 重建父 proto 代码：在被消耗的 upvalue 设置中添加 self，CALL→TAILCALL */
    int old_pn = parent->sizecode;
    int pn_cap = old_pn + 4;
    unsigned int *pn = (unsigned int *)malloc(sizeof(unsigned int) * pn_cap);
    int pni = 0;
    int call_found = 0;

    for (int i = 0; i < old_pn; i++) {
        unsigned int ins = parent->code[i];
        int op = ins & 0x3F;

        /* 在 CLOSURE 之后的被消耗 upvalue 设置中，找到 state upvalue 设置（MOVE disp_reg+1+old_sizeup, state_var）
         * 在它之后插入 self upvalue 设置 */
        if (i > closure_pos && op == LUAC_OP_MOVE) {
            int a = (ins >> 6) & 0xFF;
            int b = (ins >> 23) & 0x1FF;
            /* state upvalue 设置：A = disp_reg + 1 + old_sizeup（原 upvalue 数量），B = state_var */
            if (a == disp_reg + 1 + old_sizeup && !call_found) {
                /* 先写原来的 state MOVE */
                pn[pni++] = ins;
                /* 再写 self MOVE: A = disp_reg + 2 + old_sizeup, B = disp_reg */
                pn[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_reg + 2 + old_sizeup, disp_reg, 0);
                continue;
            }
        }

        /* CALL → TAILCALL */
        if (op == LUAC_OP_CALL && !call_found) {
            int a = (ins >> 6) & 0xFF;
            int b = (ins >> 14) & 0x1FF;
            if (a == disp_reg) {
                pn[pni++] = LUAC_ABC(LUAC_OP_TAILCALL, a, b, 0);
                call_found = 1;
                continue;
            }
        }

        /* 跳过原来的 RETURN（TAILCALL 不需要 RETURN） */
        if (op == LUAC_OP_RETURN && call_found) {
            continue;
        }

        pn[pni++] = ins;
    }

    free(parent->code);
    parent->code = pn;
    parent->sizecode = pni;
    parent->maxstacksize = (unsigned char)(disp_reg + 2 + old_sizeup + parent->numparams + 1);

    TDBG("[tailcall-U] done: dispatch sizecode=%d parent sizecode=%d\n", p->sizecode, parent->sizecode);
    return 1;
}

/* === R 模式变换：创建 dispatch 子 proto === */

static int convert_r_mode(luac_Proto *p) {
    if (!p->code || p->sizecode < 10) return 0;
    int n = p->sizecode;

    int disp_start = find_disp_start(p);
    if (disp_start < 0) return 0;
    int state_reg = find_state_reg(p, disp_start);
    if (state_reg < 0) return 0;
    if ((p->code[0] & 0x3F) != LUAC_OP_LOADK) return 0;
    int init_kidx = (p->code[0] >> 14) & 0x3FFFF;

    TDBG("[tailcall-R] state_reg=%d disp=%d\n", state_reg, disp_start);

    /* 构建 dispatch 子 proto（与原逻辑相同） */
    luac_Proto *d = (luac_Proto *)calloc(1, sizeof(luac_Proto));
    d->code_tbl = LUA_NOREF; d->k_tbl = LUA_NOREF; d->p_tbl = LUA_NOREF;
    d->lineinfo_tbl = LUA_NOREF; d->locvars_tbl = LUA_NOREF; d->upvalues_tbl = LUA_NOREF;

    d->sizek = p->sizek;
    d->k_tag = (int *)malloc(sizeof(int) * d->sizek);
    d->k_str = (char **)malloc(sizeof(char *) * d->sizek);
    d->k_str_len = (int *)malloc(sizeof(int) * d->sizek);
    d->k_num = (double *)malloc(sizeof(double) * d->sizek);
    d->k_int = (long long *)malloc(sizeof(long long) * d->sizek);
    d->k_bool = (int *)malloc(sizeof(int) * d->sizek);
    memset(d->k_str, 0, sizeof(char *) * d->sizek);
    for (int i = 0; i < d->sizek; i++) {
        d->k_tag[i] = p->k_tag[i];
        d->k_num[i] = p->k_num[i];
        d->k_int[i] = p->k_int[i];
        d->k_bool[i] = p->k_bool[i];
        if (p->k_str[i]) {
            d->k_str[i] = (char *)malloc(p->k_str_len[i] + 1);
            memcpy(d->k_str[i], p->k_str[i], p->k_str_len[i]);
            d->k_str[i][p->k_str_len[i]] = 0;
            d->k_str_len[i] = p->k_str_len[i];
        }
    }

    d->sizep = p->sizep;
    if (p->sizep > 0) {
        d->p = (luac_Proto **)malloc(sizeof(luac_Proto *) * p->sizep);
        memcpy(d->p, p->p, sizeof(luac_Proto *) * p->sizep);
    }

    int tmp = p->maxstacksize;
    int tmp2 = p->maxstacksize + 1;
    int tmp3 = p->maxstacksize + 2;
    d->maxstacksize = p->maxstacksize + 2 + p->numparams;

    int state_upval = p->sizeupvalues;
    int self_upval = p->sizeupvalues + 1;

    int cap = n * 3;
    unsigned int *nc = (unsigned int *)malloc(sizeof(unsigned int) * cap);
    int ni = 0;
    int *pos_map = (int *)malloc(sizeof(int) * (n + 1));
    int *rev_map = (int *)malloc(sizeof(int) * cap);
    for (int i = 0; i < cap; i++) rev_map[i] = -1;

    pos_map[0] = 0;
    for (int i = 1; i < n; i++) {
        pos_map[i] = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;

        if (op == LUAC_OP_EQ) {
            int b = (ins >> 23) & 0x1FF;
            if (b == state_reg) {
                nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp, state_upval, 0);
                rev_map[ni] = -1; ni++;
                ins = (ins & ~(0x1FF << 23)) | ((unsigned)tmp << 23);
            }
        }

        if (op == LUAC_OP_LOADK && a == state_reg && i + 1 < n &&
            (p->code[i+1] & 0x3F) == LUAC_OP_JMP) {
            int kidx = (ins >> 14) & 0x3FFFF;
            nc[ni] = LUAC_ABx(LUAC_OP_LOADK, tmp, kidx); rev_map[ni] = i; ni++;
            nc[ni] = LUAC_ABC(LUAC_OP_SETUPVAL, tmp, state_upval, 0); rev_map[ni] = -1; ni++;
            nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp2, self_upval, 0); rev_map[ni] = -1; ni++;
            for (int j = 0; j < p->numparams; j++) {
                nc[ni] = LUAC_ABC(LUAC_OP_MOVE, tmp3 + j, j, 0); rev_map[ni] = -1; ni++;
            }
            nc[ni] = LUAC_ABC(LUAC_OP_TAILCALL, tmp2, p->numparams + 1, 0); rev_map[ni] = -1; ni++;
            i++;
            continue;
        }

        nc[ni] = ins; rev_map[ni] = i; ni++;
    }
    pos_map[n] = ni;

    d->code = nc; d->sizecode = ni;

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
            d->code[i] = (d->code[i] & 0xFFF) | ((unsigned)(new_sbx + 131071) << 14);
        }
    }
    free(pos_map); free(rev_map);

    d->numparams = p->numparams;
    d->is_vararg = p->is_vararg;
    d->sizeupvalues = p->sizeupvalues + 2;
    d->upval_instack = (unsigned char *)malloc(d->sizeupvalues);
    d->upval_idx = (unsigned char *)malloc(d->sizeupvalues);
    d->upval_name = (char **)calloc(d->sizeupvalues, sizeof(char *));
    d->upval_name_len = (int *)calloc(d->sizeupvalues, sizeof(int));
    for (int i = 0; i < p->sizeupvalues; i++) {
        d->upval_instack[i] = 0;
        d->upval_idx[i] = i;
    }
    d->upval_instack[state_upval] = 1;
    d->upval_idx[state_upval] = 0;
    d->upval_instack[self_upval] = 1;
    d->upval_idx[self_upval] = 0;
    d->lineinfo = NULL; d->sizelineinfo = 0; d->sizelocvars = 0;
    d->source = p->source ? strdup(p->source) : NULL;
    d->source_len = p->source_len;

    /* 替换父 proto */
    int old_numparams = p->numparams;
    int state_var = old_numparams;
    int disp_reg = state_var + 1;

    p->p = realloc(p->p, sizeof(luac_Proto *) * (p->sizep + 1));
    p->p[p->sizep] = d;
    int disp_idx = p->sizep;
    p->sizep++;

    d->upval_idx[state_upval] = state_var;
    d->upval_idx[self_upval] = disp_reg;

    int upval_count = p->sizeupvalues + 2;
    int nlen = 2 + upval_count + old_numparams + 1;
    unsigned int *np = (unsigned int *)malloc(sizeof(unsigned int) * nlen);
    int pni = 0;
    np[pni++] = LUAC_ABx(LUAC_OP_LOADK, state_var, init_kidx);
    np[pni++] = LUAC_ABx(LUAC_OP_CLOSURE, disp_reg, disp_idx);
    for (int i = 0; i < p->sizeupvalues; i++) {
        np[pni++] = LUAC_ABC(LUAC_OP_GETUPVAL, disp_reg + 1 + i, i, 0);
    }
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_reg + 1 + p->sizeupvalues, state_var, 0);
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_reg + 2 + p->sizeupvalues, disp_reg, 0);
    for (int i = 0; i < old_numparams; i++) {
        np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_reg + 1 + i, i, 0);
    }
    np[pni++] = LUAC_ABC(LUAC_OP_TAILCALL, disp_reg, old_numparams + 1, 0);

    free(p->code);
    p->code = np;
    p->sizecode = pni;
    p->maxstacksize = (unsigned char)(disp_reg + upval_count + old_numparams + 1);

    TDBG("[tailcall-R] converted: parent sizecode=%d dispatch sizecode=%d\n", p->sizecode, d->sizecode);
    return 1;
}

/* === 主入口 === */

static int convert_proto(luac_Proto *p, luac_Proto *parent, int idx_in_parent) {
    if (!p->code || p->sizecode < 4) return 0;
    if (is_t_mode(p)) return 0; /* 已经是 T 模式 */

    /* 先尝试 U 模式（dispatch 子 proto，state 在 upvalue） */
    int state_upval, state_tmp;
    if (detect_u_mode(p, &state_upval, &state_tmp) && parent) {
        int ret = convert_u_mode(p, parent, idx_in_parent);
        /* U 模式检测成功但返回 0（如 nested 模式跳过），不再尝试 R 模式 */
        return ret;
    }

    /* 再尝试 R 模式（原始 flatten 状态机） */
    return convert_r_mode(p);
}

static void process_recursive(luac_Proto *p, luac_Proto *parent, int idx_in_parent, int *total) {
    if (p->p) {
        for (int i = 0; i < p->sizep; i++)
            process_recursive(p->p[i], p, i, total);
    }
    *total += convert_proto(p, parent, idx_in_parent);
}

int tailcall_chain_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    luac_sync_proto(L, 1);
    obf_invalidate_all_caches(L, p);
    int total = 0;
    process_recursive(p, NULL, -1, &total);
    lua_pushinteger(L, total);
    return 1;
}
