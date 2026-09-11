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
static int is_safe_jmp(luac_Proto *p, int pos) {
    unsigned int ins = p->code[pos];
    if ((ins & 0x3F) != 30) return 0;  /* OP_JMP */
    int A = (ins >> 6) & 0xFF;
    if (A != 0) { fprintf(stderr, "[TFJ_DBG] pos=%d skip: A=%d\n", pos, A); return 0; }
    int sbx = (int)((ins >> 14) & 0x3FFFF) - 131071;
    if (sbx >= 0) { fprintf(stderr, "[TFJ_DBG] pos=%d skip: sbx=%d>=0\n", pos, sbx); return 0; }

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
    int target = pos + 1 + sbx;
    if (target < 0 || target >= p->sizecode) { fprintf(stderr, "[TFJ_DBG] pos=%d skip: target=%d out of range\n", pos, target); return 0; }
    int target_op = p->code[target] & 0x3F;
    if (target_op == 46) { fprintf(stderr, "[TFJ_DBG] pos=%d skip: target_op=46 (EXTRAARG)\n", pos); return 0; }

    /* 跳转目标不能是跳转类或终止类指令（cfg_shuffle/for_loop_unroll 可能产生中间 JMP） */
    if (target_op == 30 || target_op == 39 || target_op == 40 || target_op == 42 ||
        target_op == 38 || target_op == 37) { fprintf(stderr, "[TFJ_DBG] pos=%d skip: target_op=%d (jump/terminator)\n", pos, target_op); return 0; }

    fprintf(stderr, "[TFJ_DBG] pos=%d ACCEPT: sbx=%d target=%d target_op=%d\n", pos, sbx, target, target_op);
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

static int convert_function(lua_State *L, luac_Proto *p) {
    int changes = 0;
    int old_max = p->maxstacksize;
    int high_reg = old_max + 2;  /* 用高寄存器，留 2 个位置给 R(A) 和 R(A+1) */

    /* 扩展 maxstacksize */
    obf_ensure_stack(p, high_reg + 2);

    int i = 0;
        while (i < p->sizecode) {
        if (is_safe_jmp(p, i)) {
            if (convert_one(L, p, i, high_reg)) {
                changes++;
                i += 2;  /* 跳过 TFORLOOP（LOADBOOL 在 pos-1，已被前一次迭代处理） */
                continue;
            }
        }
        i++;
    }

    return changes;
}

int tforloop_as_jump_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int n = convert_function(L, p);
    if (p->p) for (int i = 0; i < p->sizep; i++)
        n += convert_function(L, p->p[i]);

    lua_pushinteger(L, n);
    return 1;
}
