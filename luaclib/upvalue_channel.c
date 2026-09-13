/* upvalue_channel.c - 闭包共享通道
 *
 * 把 flatten 后的状态寄存器提升为闭包共享 upvalue。
 * 创建 dispatch 子函数，通过 upvalue 引用共享状态变量，
 * dispatcher 用 GETUPVAL 读取状态、SETUPVAL 写入状态。
 *
 * 效果：状态变量不在任何函数的寄存器中，静态分析需追踪 upvalue 流转。
 *
 * 输入：flatten 后的 proto（LOADK state + dispatcher(EQ+JMP) + blocks(LOADK state+JMP)）
 * 输出：父 proto = 初始化状态 + CLOSURE dispatch + CALL
 *       dispatch 子 proto = dispatcher(GETUPVAL+EQ) + blocks(SETUPVAL+JMP)
 */
#include "obf_util.h"
#include <string.h>

#ifndef UPCHAN_DEBUG
#define UPCHAN_DEBUG 0
#endif
#if UPCHAN_DEBUG
#define UDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define UDBG(...)
#endif

static int find_state_reg(luac_Proto *p, int disp_start) {
    int eq_counts[256] = {0};
    int loadk_at_target[256] = {0};
    int gettable_at_target[256] = {0}; /* indirect 模式：GETTABLE state_reg */
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
        /* indirect 模式：LOADK tmp + GETTABLE state_reg, table, tmp，GETTABLE 的 A 是 state_reg */
        if (op == LUAC_OP_GETTABLE && i + 1 < n) {
            int nop = p->code[i+1] & 0x3F;
            if (nop == LUAC_OP_JMP && a < 256) gettable_at_target[a]++;
        }
    }
    int best = -1, best_score = 0;
    for (int r = 0; r < 256; r++) {
        /* 标准模式：LOADK+EQ；indirect 模式：GETTABLE+EQ */
        if (eq_counts[r] >= 2 && (loadk_at_target[r] >= 2 || gettable_at_target[r] >= 2)) {
            if (eq_counts[r] > best_score) { best_score = eq_counts[r]; best = r; }
        }
    }
    return best;
}

static int find_disp_start(luac_Proto *p) {
    int n = p->sizecode;
    if (n < 4) return -1;
    int start = 1;
    if ((p->code[0] & 0x3F) == LUAC_OP_NEWTABLE) {
        /* indirect 模式：跳过表构建，找第一个 EQ */
        start = 0;
    } else if ((p->code[0] & 0x3F) != LUAC_OP_LOADK) {
        return -1;
    }
    for (int i = start; i < n - 1; i++) {
        if ((p->code[i] & 0x3F) == LUAC_OP_EQ &&
            (p->code[i+1] & 0x3F) == LUAC_OP_JMP) return i;
    }
    return -1;
}

static long long get_int_const(luac_Proto *p, int idx) {
    if (idx < 0 || idx >= p->sizek) return 0;
    if (p->k_tag[idx] == LUA_TNUMINT) return p->k_int[idx];
    if (p->k_tag[idx] == LUA_TNUMFLT) return (long long)p->k_num[idx];
    return 0;
}

static int convert_proto(lua_State *L, luac_Proto *p) {
    if (!p->code || p->sizecode < 10) return 0;
    int n = p->sizecode;

    int disp_start = find_disp_start(p);
    if (disp_start < 0) return 0;
    int state_reg = find_state_reg(p, disp_start);
    if (state_reg < 0) return 0;

    /* indirect 模式检测：code[0] 是 NEWTABLE，state 通过 GETTABLE 加载 */
    int is_indirect = ((p->code[0] & 0x3F) == LUAC_OP_NEWTABLE);
    /* nested 模式检测：code[0] LOADK outer_reg, code[1] LOADK state_reg, outer_reg > state_reg */
    int is_nested = 0;
    int outer_reg = -1;
    int init_outer_kidx = -1;
    long long init_outer = 0;
    if (!is_indirect && n >= 2 &&
        (p->code[0] & 0x3F) == LUAC_OP_LOADK &&
        (p->code[1] & 0x3F) == LUAC_OP_LOADK) {
        int a0 = (p->code[0] >> 6) & 0xFF;
        int a1 = (p->code[1] >> 6) & 0xFF;
        if (a0 > state_reg && a1 == state_reg) {
            is_nested = 1;
            outer_reg = a0;
            init_outer_kidx = (p->code[0] >> 14) & 0x3FFFF;
            init_outer = get_int_const(p, init_outer_kidx);
        }
    }
    int table_reg = -1;
    int init_end = 1; /* 初始化代码结束位置（dispatch 子 proto 从这里开始复制） */
    long long init_state = 0;
    int init_kidx = -1;

    if (is_indirect) {
        table_reg = (p->code[0] >> 6) & 0xFF;
        /* 严格验证：NEWTABLE 后必须是表构建（LOADK+LOADK+SETTABLE 重复），
         * 然后是 LOADK tmp + GETTABLE state_reg, table_reg, tmp，然后是 EQ state_reg */
        int valid = 0;
        int i = 1;
        /* 跳过表构建：至少一组 LOADK+LOADK+SETTABLE */
        while (i + 2 < n &&
               (p->code[i] & 0x3F) == LUAC_OP_LOADK &&
               (p->code[i+1] & 0x3F) == LUAC_OP_LOADK &&
               (p->code[i+2] & 0x3F) == LUAC_OP_SETTABLE &&
               ((p->code[i+2] >> 6) & 0xFF) == table_reg) {
            i += 3;
            valid = 1;
        }
        if (valid && i + 1 < n &&
            (p->code[i] & 0x3F) == LUAC_OP_LOADK &&
            (p->code[i+1] & 0x3F) == LUAC_OP_GETTABLE) {
            int ga = (p->code[i+1] >> 6) & 0xFF;
            int gb = (p->code[i+1] >> 23) & 0x1FF;
            if (ga == state_reg && gb == table_reg) {
                init_end = i + 2;
            }
        }
        if (init_end <= 1) return 0;
        UDBG("[upchan-indirect] state_reg=%d table_reg=%d init_end=%d disp=%d\n",
             state_reg, table_reg, init_end, disp_start);
    } else {
        /* 标准模式：初始状态 LOADK state_reg */
        if ((p->code[0] & 0x3F) != LUAC_OP_LOADK) return 0;
        if (is_nested) {
            init_kidx = (p->code[1] >> 14) & 0x3FFFF;
            init_end = 2; /* 跳过 outer_reg 和 state_reg 两条初始化 */
        } else {
            init_kidx = (p->code[0] >> 14) & 0x3FFFF;
            init_end = 1;
        }
        init_state = get_int_const(p, init_kidx);
        UDBG("[upchan] state_reg=%d outer_reg=%d nested=%d disp=%d init=%lld init_outer=%lld\n",
             state_reg, outer_reg, is_nested, disp_start, init_state, init_outer);
    }

    /* === 构建 dispatch 子 proto === */
    luac_Proto *d = (luac_Proto *)calloc(1, sizeof(luac_Proto));
    d->code_tbl = LUA_NOREF; d->k_tbl = LUA_NOREF; d->p_tbl = LUA_NOREF;
    d->lineinfo_tbl = LUA_NOREF; d->locvars_tbl = LUA_NOREF; d->upvalues_tbl = LUA_NOREF;

    /* 复制常量池 */
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

    /* 先固化 p 的子节点为稳定 userdata，再浅拷贝快照 */
    obf_ensure_subproto_table(L, p);
    /* 复制子 proto 列表（共享指针） */
    d->sizep = p->sizep;
    if (p->sizep > 0) {
        d->p = (luac_Proto **)malloc(sizeof(luac_Proto *) * p->sizep);
        memcpy(d->p, p->p, sizeof(luac_Proto *) * p->sizep);
    }

    int old_numparams = p->numparams;
    /* indirect 模式：table 作为额外参数传入 dispatch */
    int table_param = is_indirect ? old_numparams : -1;
    d->numparams = is_indirect ? old_numparams + 1 : old_numparams;
    d->is_vararg = p->is_vararg;

    /* tmp 寄存器：用高寄存器 */
    int tmp = p->maxstacksize;
    /* nested 模式：outer 状态也需要 tmp */
    int tmp_outer = is_nested ? p->maxstacksize + 1 : -1;
    /* indirect 模式：table 参数移到高寄存器，避免被 GETUPVAL _ENV 覆盖 */
    int table_local = is_indirect ? (is_nested ? p->maxstacksize + 2 : p->maxstacksize + 1) : -1;
    int extra_stack = 1 + (is_nested ? 1 : 0) + (is_indirect ? 1 : 0);
    d->maxstacksize = p->maxstacksize + extra_stack;

    /* state 存在 dispatch 的第 sizeupvalues 个 upvalue */
    int state_upval = p->sizeupvalues;
    /* nested 模式：outer 存在下一个 upvalue */
    int outer_upval = is_nested ? p->sizeupvalues + 1 : -1;
    int extra_upvals = 1 + (is_nested ? 1 : 0);

    /* 构建新代码：跳过初始化代码，从 dispatcher 开始
     * EQ 前插入 GETUPVAL tmp, state_upval，EQ 的 B 改 tmp
     * 标准模式：LOADK state_reg 改成 LOADK tmp + SETUPVAL tmp, state_upval
     * indirect 模式：GETTABLE state_reg, table_reg, key 改成 GETTABLE tmp, table_local, key + SETUPVAL
     */
    int cap = n * 2 + 4;
    unsigned int *nc = (unsigned int *)malloc(sizeof(unsigned int) * cap);
    int ni = 0;
    int *pos_map = (int *)malloc(sizeof(int) * (n + 1));
    int *rev_map = (int *)malloc(sizeof(int) * cap);
    for (int i = 0; i < cap; i++) rev_map[i] = -1;

    /* indirect 模式：开头把 table 参数移到高寄存器 */
    if (is_indirect) {
        nc[ni] = LUAC_ABC(LUAC_OP_MOVE, table_local, table_param, 0);
        rev_map[ni] = -1;
        ni++;
    }

    /* 跳过初始化代码（位置 0..init_end-1） */
    for (int i = 0; i < init_end; i++) pos_map[i] = ni;
    for (int i = init_end; i < n; i++) {
        pos_map[i] = ni;
        unsigned int ins = p->code[i];
        int op = ins & 0x3F;
        int a = (ins >> 6) & 0xFF;

        /* The flatten dispatcher compares state with EQ (match) and, after
        ** the binary-search rewrite, also LT (left/right descent). Every such
        ** comparison reads state in its B field; once state is moved into an
        ** upvalue below, LT/LE must be rewritten exactly like EQ or they read
        ** the now-uninitialized state register ("compare nil with number"). */
        if (op == LUAC_OP_EQ || op == LUAC_OP_LT || op == LUAC_OP_LE) {
            int b = (ins >> 23) & 0x1FF;
            if (b == state_reg) {
                nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp, state_upval, 0);
                rev_map[ni] = -1;
                ni++;
                ins = (ins & ~(0x1FFu << 23)) | ((unsigned)tmp << 23);
            } else if (is_nested && b == outer_reg) {
                nc[ni] = LUAC_ABC(LUAC_OP_GETUPVAL, tmp_outer, outer_upval, 0);
                rev_map[ni] = -1;
                ni++;
                ins = (ins & ~(0x1FFu << 23)) | ((unsigned)tmp_outer << 23);
            }
        }

        if (!is_indirect && op == LUAC_OP_LOADK && a == state_reg) {
            int kidx = (ins >> 14) & 0x3FFFF;
            nc[ni] = LUAC_ABx(LUAC_OP_LOADK, tmp, kidx);
            rev_map[ni] = i;
            ni++;
            nc[ni] = LUAC_ABC(LUAC_OP_SETUPVAL, tmp, state_upval, 0);
            rev_map[ni] = -1;
            ni++;
            continue;
        }

        /* nested 模式：LOADK outer_reg → LOADK tmp_outer + SETUPVAL tmp_outer, outer_upval */
        if (is_nested && !is_indirect && op == LUAC_OP_LOADK && a == outer_reg) {
            int kidx = (ins >> 14) & 0x3FFFF;
            nc[ni] = LUAC_ABx(LUAC_OP_LOADK, tmp_outer, kidx);
            rev_map[ni] = i;
            ni++;
            nc[ni] = LUAC_ABC(LUAC_OP_SETUPVAL, tmp_outer, outer_upval, 0);
            rev_map[ni] = -1;
            ni++;
            continue;
        }

        if (is_indirect && op == LUAC_OP_GETTABLE && a == state_reg) {
            int b = (ins >> 23) & 0x1FF;
            if (b == table_reg) {
                int c = (ins >> 14) & 0x1FF;
                nc[ni] = LUAC_ABC(LUAC_OP_GETTABLE, tmp, table_local, c);
                rev_map[ni] = i;
                ni++;
                nc[ni] = LUAC_ABC(LUAC_OP_SETUPVAL, tmp, state_upval, 0);
                rev_map[ni] = -1;
                ni++;
                continue;
            }
        }

        /* indirect 模式：把 table_reg 引用替换成 table_local（CALL 后重建表的代码） */
        if (is_indirect) {
            if (op == LUAC_OP_NEWTABLE && a == table_reg) {
                ins = (ins & ~(0xFF << 6)) | ((unsigned)table_local << 6);
            } else if (op == LUAC_OP_SETTABLE && a == table_reg) {
                ins = (ins & ~(0xFF << 6)) | ((unsigned)table_local << 6);
            }
            /* GETTABLE 的 B 是 table_reg 时也替换（非 state 加载的 GETTABLE） */
            if (op == LUAC_OP_GETTABLE) {
                int b = (ins >> 23) & 0x1FF;
                if (b == table_reg && a != state_reg) {
                    ins = (ins & ~(0x1FFu << 23)) | ((unsigned)table_local << 23);
                }
            }
        }

        nc[ni] = ins;
        rev_map[ni] = i;
        ni++;
    }
    pos_map[n] = ni;

    d->code = nc;
    d->sizecode = ni;

    /* 修正 JMP 偏移 */
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

    /* dispatch upvalue */
    d->sizeupvalues = p->sizeupvalues + extra_upvals;
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
    if (is_nested) {
        d->upval_instack[outer_upval] = 1;
        d->upval_idx[outer_upval] = 0;
    }
    d->lineinfo = NULL;
    d->sizelineinfo = 0;
    d->sizelocvars = 0;
    d->source = p->source ? strdup(p->source) : NULL;
    d->source_len = p->source_len;

    /* === 替换父 proto 代码 === */
    int state_var = old_numparams;
    int outer_var = is_nested ? state_var + 1 : -1;
    int disp_reg = is_nested ? outer_var + 1 : state_var + 1;

    /* upval_idx 必须在 add_subproto 之前设置：push_proto 会转移裸结构并置空其指针字段 */
    d->upval_idx[state_upval] = state_var;
    if (is_nested) d->upval_idx[outer_upval] = outer_var;
    /* 走 add_subproto 同步 p_tbl 镜像，避免 dump 丢子 proto */
    int disp_idx = obf_add_subproto(L, p, d);

    /* 父函数代码 */
    int upval_count = p->sizeupvalues + extra_upvals;
    int extra_args = is_indirect ? 1 : 0; /* table 参数 */
    /* table_safe：在 upvalue 设置和参数传递范围之外，避免被覆盖 */
    int table_safe = is_indirect ? (disp_reg + upval_count + old_numparams + extra_args) : -1;
    int init_count = is_indirect ? init_end + 2 : (is_nested ? 2 : 1);
    int nlen = init_count + 1 + upval_count + old_numparams + extra_args + 4; /* +vararg +pad */
    unsigned int *np = (unsigned int *)malloc(sizeof(unsigned int) * nlen);
    int pni = 0;

    if (is_indirect) {
        /* 复制表构建 + 初始化 state 代码 */
        for (int i = 0; i < init_end; i++) np[pni++] = p->code[i];
        /* MOVE state_var, state_reg（把初始化的 state 移到共享状态寄存器） */
        np[pni++] = LUAC_ABC(LUAC_OP_MOVE, state_var, state_reg, 0);
        /* MOVE table_safe, table_reg（把 table 移到安全寄存器，避免被 upvalue 设置覆盖） */
        np[pni++] = LUAC_ABC(LUAC_OP_MOVE, table_safe, table_reg, 0);
    } else {
        np[pni++] = LUAC_ABx(LUAC_OP_LOADK, state_var, init_kidx);
        if (is_nested) {
            np[pni++] = LUAC_ABx(LUAC_OP_LOADK, outer_var, init_outer_kidx);
        }
    }
    np[pni++] = LUAC_ABx(LUAC_OP_CLOSURE, disp_reg, disp_idx);
    /* 设置 dispatch 的 upvalue */
    for (int i = 0; i < p->sizeupvalues; i++) {
        np[pni++] = LUAC_ABC(LUAC_OP_GETUPVAL, disp_reg + 1 + i, i, 0);
    }
    np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_reg + 1 + p->sizeupvalues, state_var, 0);
    if (is_nested) {
        np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_reg + 2 + p->sizeupvalues, outer_var, 0);
    }
    /* 传递参数 */
    for (int i = 0; i < old_numparams; i++) {
        np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_reg + 1 + i, i, 0);
    }
    if (is_indirect) {
        /* 额外传递 table（从安全寄存器） */
        np[pni++] = LUAC_ABC(LUAC_OP_MOVE, disp_reg + 1 + old_numparams, table_safe, 0);
    }
    if (p->is_vararg) {
        /* 转发全部可变参数：VARARG B=0 + CALL B=0（多值到栈顶） */
        np[pni++] = LUAC_ABC(LUAC_OP_VARARG, disp_reg + 1 + old_numparams + extra_args, 0, 0);
        np[pni++] = LUAC_ABC(LUAC_OP_CALL, disp_reg, 0, 0);
    } else {
        np[pni++] = LUAC_ABC(LUAC_OP_CALL, disp_reg, old_numparams + 1 + extra_args, 0);
    }
    np[pni++] = LUAC_ABC(LUAC_OP_RETURN, disp_reg, 0, 0);

    free(p->code);
    p->code = np;
    p->sizecode = pni;
    int max_reg = disp_reg + upval_count + old_numparams + extra_args;
    if (is_nested && outer_var > max_reg) max_reg = outer_var;
    if (is_indirect) {
        if (table_safe > max_reg) max_reg = table_safe;
        if (table_reg + 2 > max_reg) max_reg = table_reg + 2;
        if (state_reg > max_reg) max_reg = state_reg;
    }
    p->maxstacksize = (unsigned char)(max_reg + 1);

    UDBG("[upchan] converted: parent=%d dispatch=%d numparams=%d indirect=%d\n",
         p->sizecode, d->sizecode, old_numparams, is_indirect);

#if 0 /* DEBUG: print dispatch code */
    if (is_indirect) {
        fprintf(stderr, "[upchan-dbg] PARENT maxstack=%d numparams=%d sizeupval=%d sizecode=%d\n",
                p->maxstacksize, p->numparams, p->sizeupvalues, p->sizecode);
        for (int i = 0; i < p->sizecode; i++) {
            unsigned int ins = p->code[i];
            int op = ins & 0x3F;
            int a = (ins >> 6) & 0xFF;
            int b = (ins >> 23) & 0x1FF;
            int c = (ins >> 14) & 0x1FF;
            static const char *names[] = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"};
            const char *opname = (op < 47) ? names[op] : "???";
            fprintf(stderr, "  P[%03d] %-10s A=%d B=%d C=%d\n", i, opname, a, b, c);
        }
        fprintf(stderr, "[upchan-dbg] dispatch maxstack=%d numparams=%d sizeupval=%d\n",
                d->maxstacksize, d->numparams, d->sizeupvalues);
        for (int i = 0; i < d->sizecode && i < 50; i++) {
            unsigned int ins = d->code[i];
            int op = ins & 0x3F;
            int a = (ins >> 6) & 0xFF;
            int b = (ins >> 23) & 0x1FF;
            int c = (ins >> 14) & 0x1FF;
            const char *opname = "???";
            static const char *names[] = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"};
            if (op < 47) opname = names[op];
            if (op == 30 || op == 39 || op == 40 || op == 42) {
                int sbx = ((ins >> 14) & 0x3FFFF) - 131071;
                fprintf(stderr, "  [%03d] %-10s A=%d B=%d C=%d sbx=%d tgt=%d\n", i, opname, a, b, c, sbx, i+1+sbx);
            } else {
                fprintf(stderr, "  [%03d] %-10s A=%d B=%d C=%d\n", i, opname, a, b, c);
            }
        }
    }
#endif

    return 1;
}

static void process_recursive(lua_State *L, luac_Proto *p, int *total) {
    if (p->p) {
        for (int i = 0; i < p->sizep; i++)
            process_recursive(L, p->p[i], total);
    }
    *total += convert_proto(L, p);
}

int upvalue_channel_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    luac_sync_proto(L, 1);  /* 同步所有子 proto 的 code/k 到 C 结构 */
    obf_invalidate_all_caches(L, p);
    int total = 0;
    process_recursive(L, p, &total);
    lua_pushinteger(L, total);
    return 1;
}
