/*
** condition_split.c - 条件拆分（多模式 + 与控制流扁平化联动）
**
** 把单个判断条件拆成多个判断条件，插入不透明谓词。
** 支持 4 种模式随机选择：
**   pattern 0: 恒真 TEST + 死 JMP（原模式）
**   pattern 1: 恒假条件 + 死分支（LOADBOOL(false) + TEST + JMP(跳过死代码)）
**   pattern 2: 算术不透明谓词（LOADK 0 + MUL + EQ 0，恒真）
**   pattern 3: 嵌套条件（两层 TEST 包裹原始条件）
**
** 与 flatten 联动：在模块顺序中 condition_split 应在 flatten 之前运行，
** 这样拆分出的条件分支会被 flatten 识别为独立基本块，进入分发表，
** 显著增加分发器复杂度。
*/
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "obf_util.h"

#define IS_CMP(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE)

static int ensure_const(luac_Proto *p, double val) {
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TNUMINT || p->k_tag[i] == LUA_TNUMFLT) && p->k_num[i] == val)
            return i;
    }
    return obf_add_k_number(p, val);
}

/* pattern 0: 恒真 TEST + 死 JMP
   LOADBOOL tmp, true
   TEST tmp, 0, 0       (skip next if true)
   JMP target           (dead, never taken)
   [original CMP + JMP]
*/
static int insert_pat0(luac_Proto *p, int i, int tmp_reg, int orig_target_1based) {
    int new_jmp_1based = i + 3;
    int new_target = (orig_target_1based >= i + 1) ? orig_target_1based + 3 : orig_target_1based;
    int new_sbx = new_target - new_jmp_1based - 1;
    unsigned int branch[3];
    branch[0] = LUAC_ABC(LUAC_OP_LOADBOOL, tmp_reg, 1, 0);
    branch[1] = LUAC_ABC(LUAC_OP_TEST, tmp_reg, 0, 0);
    branch[2] = LUAC_AsBx(LUAC_OP_JMP, 0, new_sbx);
    obf_code_insert(p, i + 1, branch, 3);
    return 3;
}

/* pattern 1: 恒假条件 + 死分支
   LOADBOOL tmp, false
   TEST tmp, 0, 1       (C=1: skip next if false; false -> skip)
   JMP dead_branch      (dead)
   [dead branch: LOADK tmp, 0]  -- 1 instruction dead code
   JMP past_dead
   [original CMP + JMP]
*/
static int insert_pat1(luac_Proto *p, int i, int tmp_reg, int orig_target_1based, int zero_k) {
    /* insert at i+1 (1-based):
       pc=i:   LOADBOOL false
       pc=i+1: TEST C=1
       pc=i+2: JMP to pc=i+4 (skip dead)
       pc=i+3: LOADK tmp, 0 (dead)
       pc=i+4: original CMP */
    int jmp_to_past_1based = i + 3;
    int past_dead_1based = i + 5; /* after dead LOADK */
    int sbx_skip = past_dead_1based - jmp_to_past_1based - 1; /* = 1 */
    unsigned int branch[4];
    branch[0] = LUAC_ABC(LUAC_OP_LOADBOOL, tmp_reg, 0, 0);
    branch[1] = LUAC_ABC(LUAC_OP_TEST, tmp_reg, 0, 1); /* C=1: skip if false */
    branch[2] = LUAC_AsBx(LUAC_OP_JMP, 0, sbx_skip);
    branch[3] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, zero_k); /* dead code */
    obf_code_insert(p, i + 1, branch, 4);
    /* original JMP target adjustment: target >= i+1 shifts by 4 */
    /* obf_code_insert already adjusts all jumps, but the original CMP+JMP
       is at pc=i+4 now, and its JMP target needs to account for the 4
       inserted instructions. obf_adjust_jumps_insert handles this. */
    return 4;
}

/* pattern 2: 算术不透明谓词 (x * 0 == 0 恒真)
   LOADK tmp, 0
   MOVE tmp+1, tmp     (or any register)
   MUL tmp+1, tmp+1, tmp  (tmp+1 = anything * 0 = 0)
   EQ tmp+1, K(0)       (0 == 0 -> true)
   JMP target           (dead, condition true so skip JMP... wait)
   
   Actually EQ in this Lua: if condition is TRUE, skip next JMP (fall through).
   EQ R, K -> if R == K then skip next (fall through), else JMP.
   0 == 0 is true, so skip JMP, fall through to original.
   
   LOADK tmp, 0
   LOADK tmp+1, <any number>
   MUL tmp+1, tmp+1, tmp   (tmp+1 = any * 0 = 0)
   EQ tmp+1, K(0)          (true)
   JMP dead                (skipped)
*/
static int insert_pat2(luac_Proto *p, int i, int tmp_reg, int zero_k, int one_k) {
    unsigned int branch[5];
    branch[0] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, zero_k);
    branch[1] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg + 1, one_k);
    branch[2] = LUAC_ABC(LUAC_OP_MUL, tmp_reg + 1, tmp_reg + 1, tmp_reg);
    /* EQ: A=0 (skip next if true), B=tmp+1, C=K(0) = 256+zero_k */
    branch[3] = LUAC_ABC(LUAC_OP_EQ, 0, tmp_reg + 1, 0x100 + zero_k);
    /* JMP dead: target = original target, but shifted. obf_code_insert adjusts.
       We set sbx to point past original CMP+JMP (same as original target).
       Since original JMP is at pc=i+1 (before insert), after 5 inserts it's at i+6.
       The dead JMP at pc=i+4 should jump to the same target as original JMP. */
    /* We'll just set a placeholder and let the original JMP handle it.
       Actually the dead JMP needs a valid target. Jump to pc=i+6 (original CMP).
       Wait no - if EQ is true, we SKIP this JMP and fall to original CMP.
       If EQ is false (impossible), we take this JMP. Jump to original target. */
    /* For simplicity, jump to the instruction after original JMP (the "else" target).
       Original JMP target 1-based = orig_target. After 5 inserts, shifts by 5 if >= i+1.
       Dead JMP 1-based pos = i+5. target 1-based = orig_target + 5 (if >= i+1).
       sbx = target - pos - 1. */
    /* We don't know orig_target here cleanly; use a forward jump to pc=i+7
       (past original CMP at i+5 and JMP at i+6) as a safe dead target.
       Actually that would skip the original condition entirely if taken.
       Better: dead JMP jumps to original JMP's target. Let's compute. */
    /* We'll set sbx to jump forward 2 (to original CMP's JMP instruction),
       which then jumps to the real target. This creates a double-jump. */
    branch[4] = LUAC_AsBx(LUAC_OP_JMP, 0, 1); /* jump to next instruction (original CMP) */
    obf_code_insert(p, i + 1, branch, 5);
    return 5;
}

/* pattern 3: 嵌套条件（两层 TEST 包裹）
   LOADBOOL tmp, true
   TEST tmp, 0, 0    (skip next)
   JMP dead1         (dead)
   LOADBOOL tmp, false
   TEST tmp, 0, 1    (skip next if false -> skip)
   JMP dead2         (dead)
   [original CMP + JMP]
*/
static int insert_pat3(luac_Proto *p, int i, int tmp_reg) {
    unsigned int branch[6];
    branch[0] = LUAC_ABC(LUAC_OP_LOADBOOL, tmp_reg, 1, 0);
    branch[1] = LUAC_ABC(LUAC_OP_TEST, tmp_reg, 0, 0);
    branch[2] = LUAC_AsBx(LUAC_OP_JMP, 0, 3); /* skip to second TEST group */
    branch[3] = LUAC_ABC(LUAC_OP_LOADBOOL, tmp_reg, 0, 0);
    branch[4] = LUAC_ABC(LUAC_OP_TEST, tmp_reg, 0, 1);
    branch[5] = LUAC_AsBx(LUAC_OP_JMP, 0, 0); /* dead, skipped */
    obf_code_insert(p, i + 1, branch, 6);
    return 6;
}

static int split_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 3 || count <= 0) return 0;

    int old_maxstack = p->maxstacksize;
    int extra = 3;
    if (old_maxstack + extra > 250) extra = 250 - old_maxstack;
    if (extra < 2) return 0;
    int tmp_reg = old_maxstack;
    obf_ensure_stack(p, old_maxstack + extra);

    int zero_k = ensure_const(p, 0.0);
    int one_k = ensure_const(p, 1.0);

    int changes = 0;
    int i = 0;
    while (i < p->sizecode - 1 && changes < count) {
        int op = p->code[i] & 0x3F;
        int next_op = p->code[i + 1] & 0x3F;

        if (IS_CMP(op) && next_op == LUAC_OP_JMP) {
            /* 保存原始 JMP 目标（1-based） */
            unsigned int jmp_inst = p->code[i + 1];
            int orig_sbx = (int)(jmp_inst >> 14) - 131071;
            int orig_target_1based = (i + 2) + orig_sbx + 1;

            int pattern = obf_rand() % 4;
            int inserted = 0;
            switch (pattern) {
                case 0: inserted = insert_pat0(p, i, tmp_reg, orig_target_1based); break;
                case 1: inserted = insert_pat1(p, i, tmp_reg, orig_target_1based, zero_k); break;
                case 2: inserted = insert_pat2(p, i, tmp_reg, zero_k, one_k); break;
                case 3: inserted = insert_pat3(p, i, tmp_reg); break;
            }
            if (inserted > 0) {
                changes++;
                i += inserted; /* skip inserted instructions */
            }
        }
        i++;
    }

    if (changes > 0) {
        if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
        p->sizelineinfo = 0;
    }
    return changes;
}

int condition_split_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    int count = 8;
    if (lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    int total = split_function(p, count);
    int sub_count = count > 1 ? count / 2 : 1;
    for (int i = 0; i < p->sizep; i++) {
        total += split_function(p->p[i], sub_count);
    }
    obf_invalidate_all_caches(L, p);
    lua_pushinteger(L, total);
    return 1;
}
