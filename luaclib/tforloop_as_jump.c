/*
 * tforloop_as_jump.c - TFORLOOP 复用为混淆跳转
 *
 * TFORLOOP A sBx 语义：if R(A+1) ~= nil then R(A) = R(A+1); pc += sBx end
 *
 * 利用其条件复制语义，把部分回跳 JMP 改成 TFORLOOP：
 * 1. 用高寄存器 A（>= 原 maxstacksize），不干扰真实代码
 * 2. 在 JMP 前插入 LOADBOOL R(A+1), 1, 0（设置为 true，非 nil）
 * 3. 把 JMP 改成 TFORLOOP A, sBx（条件总为真，等价于无条件跳转 + R(A)=R(A+1)）
 *
 * 反编译器看到 TFORLOOP 会尝试匹配 TFORCALL，但前面没有 TFORCALL，
 * 且 TFORLOOP 的 A 寄存器指向高寄存器（不是迭代器循环变量位置），
 * 反编译器无法还原成普通 JMP，也无法识别为迭代器循环。
 *
 * 关键：必须真的用到 R(A+1)~=nil 判断和 R(A)=R(A+1) 复制，
 * 不能只是空壳跳转（否则语义不等价）。这里 LOADBOOL 设置 true，
 * TFORLOOP 执行 R(A)=true 的复制是真实发生的。
 *
 * sBx 修正：先把 JMP 改成 TFORLOOP（保持原 sBx），再插入 LOADBOOL，
 * 这样 obf_code_insert 内部的 obf_adjust_jumps_insert 会自动修正 TFORLOOP 的 sBx。
 * 不能先插入再覆盖（会覆盖掉修正后的 sBx）。
 */

#include "obf_util.h"


/* 判断是否是可以安全替换的回跳 JMP */
static int tfj_jump_target(unsigned int ins, int pc) {
    int op = ins & 0x3F;
    if (op == 30 || op == 39 || op == 40 || op == 42) {
        int sbx = (int)((ins >> 14) & 0x3FFFF) - 131071;
        return pc + 1 + sbx;
    }
    return -1000000;
}

static int is_safe_jmp(luac_Proto *p, int pos) {
    unsigned int ins = p->code[pos];
    if ((ins & 0x3F) != 30) return 0;  /* OP_JMP */
    int A = (ins >> 6) & 0xFF;
    if (A != 0) return 0;
    int sbx = (int)((ins >> 14) & 0x3FFFF) - 131071;
    if (sbx >= 0) return 0;

    /* TFORLOOP 的跳转条件是 R(A+1) ~= nil，与条件指令（EQ/LT/LE/TEST/TESTSET）的结果无关。
       所以只能替换无条件 JMP（前面不是条件指令的 JMP）。条件跳转后的 JMP 不能替换，
       否则 TFORLOOP 会忽略条件指令的结果，总是跳转，导致死循环。 */
    if (pos > 0) {
        int prev_op = p->code[pos - 1] & 0x3F;
        /* EQ/LT/LE/TEST/TESTSET 之后必须是 JMP，且 JMP 是条件跳转，不能替换 */
        if (prev_op == 31 || prev_op == 32 || prev_op == 33 ||
            prev_op == 34 || prev_op == 35) return 0;
        /* LOADKX 之后必须是 EXTRAARG */
        if (prev_op == 2) return 0;
        /* SETLIST C=0 之后必须是 EXTRAARG */
        if (prev_op == 43) {
            int c = (p->code[pos - 1] >> 14) & 0x1FF;
            if (c == 0) return 0;
        }
    }

    /* 跳转目标不能是 EXTRAARG */
    /* After inserting LOADBOOL at pos, the new TFORLOOP sits at pos+1.
       Reject if any other jump edge lands directly on pos+1 (it would skip
       the LOADBOOL that primes R(A+1), making TFORLOOP's test nondeterministic). */
    for (int _j = 0; _j < p->sizecode; _j++) {
        int t = tfj_jump_target(p->code[_j], _j);
        if (t <= -100000) continue;
        if (t >= pos) t++;  /* account for the inserted instruction */
        if (t == pos + 1) return 0;
    }

    int target = pos + 1 + sbx;
    if (target < 0 || target >= p->sizecode) return 0;
    int target_op = p->code[target] & 0x3F;
    if (target_op == 46) return 0;

    /* 跳转目标不能是跳转类或终止类指令（cfg_shuffle/for_loop_unroll 可能产生中间 JMP） */
    if (target_op == 30 || target_op == 39 || target_op == 40 || target_op == 42 ||
        target_op == 38 || target_op == 37) return 0;

    /* candidate accepted */
    return 1;
}

static int convert_one(lua_State *L, luac_Proto *p, int pos, int high_reg) {
    /* LOADBOOL 插入到 pos-1（如果 pos > 0），避免破坏条件指令+JMP 配对。
       pos=0 时插入到 pos（JMP 之前）。
       先插入 LOADBOOL，obf_code_insert 内部的 obf_adjust_jumps_insert 会自动修正 JMP 的 sBx，
       然后再把 JMP 改成 TFORLOOP（使用修正后的 sBx）。 */
    unsigned int loadbool = LUAC_ABC(3, high_reg + 1, 1, 0);  /* OP_LOADBOOL */
    /* obf_code_insert 的 pos 是 1-based。想在 0-based 位置 pos（JMP 之前）插入，
       对应 1-based 位置 pos+1。这样不会破坏 JMP 之前的条件指令+JMP 配对。 */
    int insert_pos = pos + 1;  /* 1-based，对应 0-based 位置 pos */
    obf_code_insert(p, insert_pos, &loadbool, 1);

    /* JMP 现在在 pos+1（0-based，因为插入了一条指令） */
    int jmp_pos = pos + 1;
    unsigned int ins = p->code[jmp_pos];
    int sbx = (int)((ins >> 14) & 0x3FFFF) - 131071;
    p->code[jmp_pos] = LUAC_AsBx(42, high_reg, sbx);  /* OP_TFORLOOP */

    return 1;
}

static int proto_has_candidate(luac_Proto *p) {
    int high_reg = (int)p->maxstacksize + 2;
    if (high_reg + 2 > 250) return 0;  /* no room under register cap */
    for (int q = 0; q < p->sizecode; q++)
        if (is_safe_jmp(p, q)) return 1;
    return 0;
}

static int convert_function(lua_State *L, luac_Proto *p) {
    int changes = 0;
    int old_max = p->maxstacksize;
    int high_reg = old_max + 2;  /* high regs: R(A),R(A+1) */
    if (high_reg + 2 > 250) return 0;
    /* 无候选零副作用：不抬高 maxstacksize（事后抬栈会让依赖 ci->top 的前置模块
       变长指令错位，见 process 处说明）。 */
    if (!proto_has_candidate(p)) return 0;
    obf_ensure_stack(p, high_reg + 2);

    int i = 0;
    while (i < p->sizecode) {
        if (is_safe_jmp(p, i)) {
            if (convert_one(L, p, i, high_reg)) {
                changes++;
                i += 2;
                continue;
            }
        }
        i++;
    }
    return changes;
}

int tforloop_as_jump_process(lua_State *L) {
    luac_Proto *root = obf_check_proto(L);
    int total = 0;

    /* 根因修复（原问题2：tforloop_as_jump + 多常量模块 -> _ENV/算术 nil）：
       只对"本 proto 确有可替换回跳 JMP"的 proto 失效其【本层】缓存并转换；
       无候选的 proto 完全不碰——不递归失效其子孙缓存、不抬高其 maxstacksize。
       旧实现在 changes=0 时仍对整棵树 obf_invalidate_all_caches（递归），把权威
       从 Lua 缓存表切到可能过时的 C 镜像，前置 const_hide/str_encrypt 等模块的
       修改在重建中丢失，运行即 arithmetic on nil / _ENV 被索引成 number。
       堆堆栈遍历，规避 WASM 64KB 栈限制。 */
    int cap = 16, cnt = 0;
    luac_Proto **stk = (luac_Proto **)luac_alloc(sizeof(luac_Proto *) * cap);
    stk[cnt++] = root;
    while (cnt > 0) {
        luac_Proto *cur = stk[--cnt];
        if (cur->p) for (int i = 0; i < cur->sizep; i++) {
            if (cnt >= cap) { cap *= 2; stk = (luac_Proto **)realloc(stk, sizeof(luac_Proto *) * cap); }
            stk[cnt++] = cur->p[i];
        }
        if (proto_has_candidate(cur)) {
            obf_invalidate_self_caches(L, cur);
            total += convert_function(L, cur);
        }
    }
    free(stk);

    lua_pushinteger(L, total);
    return 1;
}
