/* exception_dispatcher.c
 *
 * 加强版异常驱动控制流：
 * 把 flatten 后的整个状态机包装进一个 runner 子函数，
 * 状态转移点从 LOADK state + JMP dispatcher 改为 error(next_state)，
 * 外层用 while + pcall(runner, code) 捕获 error 并驱动下一轮。
 *
 * 结构：
 *   runner(code):  MOVE state_reg, code
 *                  dispatcher (EQ+JMP, 保留)
 *                  blocks...  (末尾改为 error(next))
 *                  RETURN      (正常结束)
 *
 *   parent:        CLOSURE runner
 *                  GETTABUP pcall
 *                  LOADK code, initial
 *                  while:  MOVE arg1, runner
 *                          MOVE arg2, code
 *                          CALL pcall, 3, 3   -> ok, v
 *                          TEST ok, 0, 0
 *                          JMP break
 *                          MOVE code, v
 *                          JMP while
 *                  break:  RETURN v, 2
 */
#include "obf_util.h"
#include <string.h>

#ifndef EXCDISP_DEBUG
#define EXCDISP_DEBUG 0
#endif
#if EXCDISP_DEBUG
#define EDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define EDBG(...)
#endif

/* ---- flatten 结构识别（与 exception_flow 一致） ---- */

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
    if ((p->code[0] & 0x3F) != LUAC_OP_LOADK) return -1;
    for (int i = 1; i < n - 1; i++) {
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

static int find_env_upval(luac_Proto *p) {
    static const char *gnames[] = {"print","pcall","error","tostring","type",
        "pairs","ipairs","select","setmetatable","getmetatable","tonumber",
        "string","table","math","io","os",NULL};
    for (int i = 0; i < p->sizecode; i++) {
        if ((p->code[i] & 0x3F) != LUAC_OP_GETTABUP) continue;
        int b = (p->code[i] >> 23) & 0x1FF;
        int c = (p->code[i] >> 14) & 0x1FF;
        if (c < 256 || c - 256 >= p->sizek) continue;
        int ki = c - 256;
        if (p->k_tag[ki] != LUA_TSTRING || !p->k_str[ki]) continue;
        for (int g = 0; gnames[g]; g++)
            if (strcmp(p->k_str[ki], gnames[g]) == 0) return b;
    }
    return -1;
}

static int get_string_const_idx(luac_Proto *p, const char *s) {
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TSTRING && p->k_str[i] &&
            strcmp(p->k_str[i], s) == 0) return i;
    }
    return obf_add_k_string(p, s, strlen(s));
}

static int get_int_const_idx(luac_Proto *p, long long val) {
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TNUMINT && p->k_int[i] == val) return i;
        if (p->k_tag[i] == LUA_TNUMFLT && p->k_num[i] == (double)val) return i;
    }
    return obf_add_k_integer(p, val);
}

/* ---- 核心：把一个 flatten 后的 proto 转为 while+pcall dispatcher ---- */

static int convert_proto(lua_State *L, luac_Proto *p) {
    if (!p->code || p->sizecode < 10) return 0;
    int n = p->sizecode;

    int disp_start = find_disp_start(p);
    if (disp_start < 0) return 0;
    int state_reg = find_state_reg(p, disp_start);
    if (state_reg < 0) return 0;

    /* 初始状态：code[0] = LOADK state_reg, K(init_idx) */
    if ((p->code[0] & 0x3F) != LUAC_OP_LOADK) return 0;
    int init_kidx = (p->code[0] >> 14) & 0x3FFFF;
    long long init_state = get_int_const(p, init_kidx);

    /* 找 _ENV upvalue */
    int env_upval = find_env_upval(p);
    if (env_upval < 0) return 0;

    /* 收集状态转移点：LOADK state_reg + JMP to disp_start */
    int tpos[256], tcount = 0;
    long long tsid[256];
    for (int i = disp_start; i < n - 1; i++) {
        if ((p->code[i] & 0x3F) != LUAC_OP_LOADK) continue;
        int a = (p->code[i] >> 6) & 0xFF;
        if (a != state_reg) continue;
        if ((p->code[i+1] & 0x3F) != LUAC_OP_JMP) continue;
        int sbx = ((p->code[i+1] >> 14) & 0x3FFFF) - 131071;
        int target = i + 1 + 1 + sbx;
        if (target != disp_start) continue;
        int kidx = (p->code[i] >> 14) & 0x3FFFF;
        if (tcount < 256) {
            tpos[tcount] = i;
            tsid[tcount] = get_int_const(p, kidx);
            tcount++;
        }
    }
    if (tcount == 0) return 0;

    EDBG("[exc_disp] state_reg=%d disp=%d init=%lld trans=%d env=%d\n",
         state_reg, disp_start, init_state, tcount, env_upval);

    /* === 构建 runner sub-proto === */
    luac_Proto *r = (luac_Proto *)calloc(1, sizeof(luac_Proto));

    /* 复制常量池 */
    r->sizek = p->sizek;
    r->k_tag = (int *)malloc(sizeof(int) * r->sizek);
    r->k_str = (char **)malloc(sizeof(char *) * r->sizek);
    r->k_str_len = (int *)malloc(sizeof(int) * r->sizek);
    r->k_num = (double *)malloc(sizeof(double) * r->sizek);
    r->k_int = (long long *)malloc(sizeof(long long) * r->sizek);
    r->k_bool = (int *)malloc(sizeof(int) * r->sizek);
    memset(r->k_str, 0, sizeof(char *) * r->sizek);
    for (int i = 0; i < r->sizek; i++) {
        r->k_tag[i] = p->k_tag[i];
        r->k_num[i] = p->k_num[i];
        r->k_int[i] = p->k_int[i];
        r->k_bool[i] = p->k_bool[i];
        if (p->k_str[i]) {
            r->k_str[i] = (char *)malloc(p->k_str_len[i] + 1);
            memcpy(r->k_str[i], p->k_str[i], p->k_str_len[i]);
            r->k_str[i][p->k_str_len[i]] = 0;
            r->k_str_len[i] = p->k_str_len[i];
        }
    }
    int kerr = get_string_const_idx(r, "error");

    /* 复制子 proto 列表（共享指针） */
    r->sizep = p->sizep;
    if (p->sizep > 0) {
        r->p = (luac_Proto **)malloc(sizeof(luac_Proto *) * p->sizep);
        memcpy(r->p, p->p, sizeof(luac_Proto *) * p->sizep);
    }

    /* 构建 runner code：先复制，再修改 */
    /* 每个状态转移点 2 条 -> 3 条 (GETTABUP+LOADK+CALL)，净增 1 条 */
    /* 开头 LOADK 替换为 MOVE（条数不变） */
    int extra = tcount; /* 每个转移点 +1 */
    r->sizecode = n + extra;
    r->code = (unsigned int *)malloc(sizeof(unsigned int) * r->sizecode);
    memcpy(r->code, p->code, sizeof(unsigned int) * n);

    /* 开头：LOADK state, K(init) -> MOVE state, R0 (参数) */
    r->code[0] = LUAC_ABC(LUAC_OP_MOVE, state_reg, 0, 0);

    /* 替换状态转移点为 error(sid)，从后往前 */
    int rc = n; /* 当前长度 */
    for (int t = tcount - 1; t >= 0; t--) {
        int pos = tpos[t];
        long long sid = tsid[t];
        int kidx = get_int_const_idx(r, sid);

        /* 插入 1 条在 pos+2 */
        memmove(&r->code[pos + 3], &r->code[pos + 2],
                sizeof(unsigned int) * (rc - pos - 2));
        rc++;
        /* 3 条替换原来的 2 条 */
        int tmp = p->maxstacksize; /* 高寄存器 */
        r->code[pos]     = LUAC_ABC(LUAC_OP_GETTABUP, tmp, 0, kerr + LUAC_BITRK);
        r->code[pos + 1] = LUAC_ABx(LUAC_OP_LOADK, tmp + 1, kidx);
        r->code[pos + 2] = LUAC_ABC(LUAC_OP_CALL, tmp, 2, 1);
    }
    r->sizecode = rc;

    /* 修正 runner 中所有 JMP 偏移（因为插入了指令） */
    /* 简单方式：重新计算所有 JMP 的目标。由于插入点已知，用 obf_adjust_jumps_insert */
    /* 但我们已经从后往前插入，每次插入后位置都变了。需要在插入时修正。 */
    /* 实际上上面的替换有问题：插入后后续 JMP 偏移没有修正。 */
    /* 用一个更简单的方法：先构建新代码数组，逐条复制，遇到转移点替换。 */

    /* 重新构建 runner code */
    free(r->code);
    unsigned int *rcode = (unsigned int *)malloc(sizeof(unsigned int) * (n + extra));
    int ri = 0;
    int ti = 0; /* 下一个要处理的转移点索引（按位置升序） */
    /* tpos 是按扫描顺序（升序）收集的 */
    for (int i = 0; i < n; i++) {
        if (ti < tcount && i == tpos[ti]) {
            long long sid = tsid[ti];
            int kidx = get_int_const_idx(r, sid);
            int tmp = p->maxstacksize;
            rcode[ri++] = LUAC_ABC(LUAC_OP_GETTABUP, tmp, 0, kerr + LUAC_BITRK);
            rcode[ri++] = LUAC_ABx(LUAC_OP_LOADK, tmp + 1, kidx);
            rcode[ri++] = LUAC_ABC(LUAC_OP_CALL, tmp, 2, 1);
            i++; /* 跳过原来的 JMP */
            ti++;
        } else {
            rcode[ri++] = p->code[i];
        }
    }
    r->code = rcode;
    r->sizecode = ri;

    /* 修正 JMP 偏移：建立位置映射 old_pos -> new_pos */
    /* 重新计算映射 */
    int *pos_map = (int *)malloc(sizeof(int) * (n + 1));
    int ni = 0;
    ti = 0;
    /* walk manually: a transition occupies TWO old slots (LOADK+JMP) and
     * becomes THREE new slots, so BOTH pos_map[i] and pos_map[i+1] must be
     * defined (the skipped JMP slot maps to just past the new block) */
    for (int i = 0; i <= n; ) {
        pos_map[i] = ni;
        if (i < n && ti < tcount && i == tpos[ti]) {
            ni += 3;
            pos_map[i + 1] = ni;
            i += 2; ti++;
        } else { ni++; i++; }
    }
    /* 修正所有 JMP/FORLOOP/FORPREP/TFORLOOP */
    for (int i = 0; i < r->sizecode; i++) {
        int op = r->code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP ||
            op == LUAC_OP_FORPREP || op == LUAC_OP_TFORLOOP) {
            int sbx = ((r->code[i] >> 14) & 0x3FFFF) - 131071;
            /* 这条指令在新代码中的位置是 i，需要找到它在旧代码中的位置 */
            /* 用反向映射 */
            /* 简化：遍历旧位置找到对应的新位置 */
            int old_i = -1;
            for (int j = 0; j <= n; j++) {
                if (pos_map[j] == i) { old_i = j; break; }
            }
            if (old_i < 0) continue;
            int old_target = old_i + 1 + sbx;
            if (old_target < 0 || old_target > n) continue;
            int new_target = pos_map[old_target];
            int new_sbx = new_target - i - 1;
            r->code[i] = (r->code[i] & 0x3FFF) | ((unsigned)(new_sbx + 131071) << 14);
        }
    }
    free(pos_map);

    /* runner 基本属性 */
    r->numparams = 1;
    r->is_vararg = 0;
    r->maxstacksize = p->maxstacksize + 2;
    r->sizeupvalues = 1;
    r->upval_instack = (unsigned char *)malloc(1);
    r->upval_idx = (unsigned char *)malloc(1);
    r->upval_instack[0] = 0;
    r->upval_idx[0] = 0;
    r->lineinfo = NULL;
    r->sizelineinfo = 0;
    r->sizelocvars = 0;
    r->source = p->source ? strdup(p->source) : NULL;
    r->source_len = p->source_len;
    r->linedefined = 0;
    r->lastlinedefined = 0;

    /* === 替换 parent 代码为 while+pcall === */
    int runner_reg = p->maxstacksize;
    int pcall_reg = runner_reg + 1;
    int code_reg = runner_reg + 2;
    int need_stack = pcall_reg + 3;
    if (need_stack > 250) { free(r->code); free(r); return 0; }

    int kpcall = get_string_const_idx(p, "pcall");
    int kinit = get_int_const_idx(p, init_state);

    /* 把 runner 加到子 proto 列表（走 add_subproto 同步 p_tbl 镜像） */
    int runner_idx = obf_add_subproto(L, p, r);

    /* 构建新代码 */
    unsigned int np[16];
    int ni2 = 0;
    np[ni2++] = LUAC_ABx(LUAC_OP_CLOSURE, runner_reg, runner_idx);
    np[ni2++] = LUAC_ABC(LUAC_OP_GETUPVAL, runner_reg + 1, env_upval, 0); /* consumed: upval[0]=_ENV */
    np[ni2++] = LUAC_ABC(LUAC_OP_GETTABUP, pcall_reg, env_upval, kpcall + LUAC_BITRK);
    np[ni2++] = LUAC_ABx(LUAC_OP_LOADK, code_reg, kinit);
    int while_pos = ni2;
    np[ni2++] = LUAC_ABC(LUAC_OP_MOVE, pcall_reg + 1, runner_reg, 0);
    np[ni2++] = LUAC_ABC(LUAC_OP_MOVE, pcall_reg + 2, code_reg, 0);
    np[ni2++] = LUAC_ABC(LUAC_OP_CALL, pcall_reg, 3, 3); /* ok, v = pcall(runner, code) */
    np[ni2++] = LUAC_ABC(LUAC_OP_TEST, pcall_reg, 0, 0); /* if ok==false skip JMP */
    int break_jmp_pos = ni2;
    np[ni2++] = 0; /* JMP break — placeholder */
    np[ni2++] = LUAC_ABC(LUAC_OP_MOVE, code_reg, pcall_reg + 1, 0); /* code = v */
    np[ni2++] = LUAC_AsBx(LUAC_OP_JMP, 0, while_pos - ni2 - 1); /* JMP while */
    int break_pos = ni2;
    np[ni2++] = LUAC_ABC(LUAC_OP_RETURN, pcall_reg + 1, 2, 0); /* return v */

    /* 填充 break JMP */
    np[break_jmp_pos] = LUAC_AsBx(LUAC_OP_JMP, 0, break_pos - break_jmp_pos - 1);

    /* 替换 parent code */
    free(p->code);
    p->code = (unsigned int *)malloc(sizeof(unsigned int) * ni2);
    memcpy(p->code, np, sizeof(unsigned int) * ni2);
    p->sizecode = ni2;
    p->maxstacksize = (unsigned char)need_stack;

    EDBG("[exc_disp] converted: new sizecode=%d runner sizecode=%d\n",
         p->sizecode, r->sizecode);
    return 1;
}

static void process_recursive(lua_State *L, luac_Proto *p, int *total) {
    if (p->p) for (int i = 0; i < p->sizep; i++)
        process_recursive(L, p->p[i], total);
    *total += convert_proto(L, p);
}

int exception_dispatcher_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);
    int total = 0;
    process_recursive(L, p, &total);
    lua_pushinteger(L, total);
    return 1;
}
