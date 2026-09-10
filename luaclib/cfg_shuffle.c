/*
 * cfg_shuffle.c - CFG基本块重排
 *
 * 把基本块物理顺序随机打乱，块之间用JMP连接。
 * 与控制流扁平化(flatten)不同：不用分发器，只是物理重排。
 * 反编译器按物理顺序解析时看到混乱的控制流。
 *
 * 算法：
 * 1. 识别基本块边界（跳转目标 + 终止指令后一条）
 * 2. 构建块列表，确定每个块的后继（JMP目标 + fall-through）
 * 3. 随机打乱块顺序（保留块0为入口）
 * 4. 重建指令数组，fall-through后继不是下一块时插入JMP
 * 5. 修正所有JMP的sBx
 */

#include "obf_util.h"
#include <stdlib.h>
#include <string.h>

#define CFG_SHUFFLE_DEBUG 0

typedef struct {
    int start;       /* 原始起始位置 */
    int end;         /* 原始结束位置(不含) */
    int succ[2];     /* 后继块索引 */
    int nsucc;
    int fall_succ;   /* fall-through后继块索引, -1表示无 */
    int jmp_target;  /* JMP目标块索引, -1表示无 */
} Block;

/* 终止指令：块的最后一条指令 */
static int is_terminator(int op) {
    return op == 30 ||  /* JMP */
           op == 38 ||  /* RETURN */
           op == 37 ||  /* TAILCALL */
           op == 39 ||  /* FORLOOP */
           op == 40 ||  /* FORPREP */
           op == 42;    /* TFORLOOP */
}

/* 条件指令：后面必须跟JMP */
static int is_conditional(int op) {
    return op == 31 ||  /* EQ */
           op == 32 ||  /* LT */
           op == 33 ||  /* LE */
           op == 34 ||  /* TEST */
           op == 35 ||  /* TESTSET */
           op == 41;    /* TFORCALL (后跟TFORLOOP) */
}

/* 获取JMP类指令的sBx */
static int get_sbx(unsigned int ins) {
    int bx = (ins >> 14) & 0x3FFFF;
    return bx - 131071;
}

/* 设置JMP类指令的sBx */
static unsigned int set_sbx(unsigned int ins, int sbx) {
    int bx = sbx + 131071;
    return (ins & 0x3FFF) | ((bx & 0x3FFFF) << 14);
}


/* Find block containing target position (fallback when target is not a block start,
   e.g. post-CLOSURE upvalue setup or post-TFORCALL) */
static int find_block_containing(Block *blocks, int nblocks, int target) {
    for (int tb = 0; tb < nblocks; tb++) {
        if (blocks[tb].start <= target && target < blocks[tb].end) return tb;
    }
    return -1;
}

/* Protect inseparable instruction pairs: clear block starts that fall
   in the middle of CLOSURE+upvalues, conditional+JMP, LOADKX+EXTRAARG,
   SETLIST C=0+EXTRAARG, TFORCALL+TFORLOOP. */
static void protect_inseparable_regions(int *is_start, unsigned int *code, int sizecode) {
    for (int i = 0; i < sizecode; i++) {
        int op = code[i] & 0x3F;
        if (op == 44) {  /* CLOSURE: skip following upvalue setup (MOVE/GETUPVAL/GETTABUP) */
            int j = i + 1;
            while (j < sizecode) {
                int uop = code[j] & 0x3F;
                if (uop == 0 || uop == 5 || uop == 6) {  /* MOVE, GETUPVAL, GETTABUP */
                    is_start[j] = 0;
                    j++;
                } else {
                    break;
                }
            }
        } else if (op == 31 || op == 32 || op == 33 || op == 34 || op == 35) {
            /* EQ/LT/LE/TEST/TESTSET: must be followed by JMP */
            if (i + 1 < sizecode && (code[i+1] & 0x3F) == 30) {
                is_start[i + 1] = 0;
            }
        } else if (op == 2) {  /* LOADKX: must be followed by EXTRAARG */
            if (i + 1 < sizecode && (code[i+1] & 0x3F) == 46) {
                is_start[i + 1] = 0;
            }
        } else if (op == 43) {  /* SETLIST: C=0 must be followed by EXTRAARG */
            int c = (code[i] >> 14) & 0x1FF;
            if (c == 0 && i + 1 < sizecode && (code[i+1] & 0x3F) == 46) {
                is_start[i + 1] = 0;
            }
        } else if (op == 3) {  /* LOADBOOL: C=1 skips next instruction (PC+=1) */
            int c = (code[i] >> 14) & 0x1FF;
            if (c == 1 && i + 1 < sizecode) {
                is_start[i + 1] = 0;
            }
        } else if (op == 41) {  /* TFORCALL: must be followed by TFORLOOP */
            if (i + 1 < sizecode && (code[i+1] & 0x3F) == 42) {
                is_start[i + 1] = 0;
            }
        }
    }
}

static int cfg_shuffle_process_sub(luac_Proto *p);

int cfg_shuffle_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    if (p->sizecode < 6) {
        lua_pushinteger(L, 0);
        return 1;
    }

    /* === 步骤1: 标记块起始位置 === */
    int *is_start = (int *)calloc(p->sizecode, sizeof(int));
    is_start[0] = 1;

    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (is_terminator(op)) {
            /* 标记跳转目标 */
            int sbx = get_sbx(p->code[i]);
            int target = i + 1 + sbx;
            if (target >= 0 && target < p->sizecode) {
                is_start[target] = 1;
            }
            /* 标记下一条指令为块起始 */
            if (i + 1 < p->sizecode) {
                is_start[i + 1] = 1;
            }
        }
    }

    /* Protect all inseparable instruction pairs from being split across blocks */
    protect_inseparable_regions(is_start, p->code, p->sizecode);

    /* === 步骤2: 构建块列表 === */
    int nblocks = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if (is_start[i]) nblocks++;
    }

#if CFG_SHUFFLE_DEBUG
    fprintf(stderr, "[cfg_shuffle] sizecode=%d nblocks=%d\n", p->sizecode, nblocks);
    for (int _i = 0; _i < p->sizecode; _i++) {
        int _op = p->code[_i] & 0x3F;
        int _a = (p->code[_i] >> 6) & 0xFF;
        int _bx = (p->code[_i] >> 14) & 0x3FFFF;
        fprintf(stderr, "  [%02d] op=%d A=%d bx=%d sbx=%d start=%d\n", _i, _op, _a, _bx, _bx - 131072, is_start[_i]);
    }
#endif

    if (nblocks < 3) {
        free(is_start);
        lua_pushinteger(L, 0);
        return 1;
    }

    Block *blocks = (Block *)malloc(sizeof(Block) * nblocks);
    int bi = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if (is_start[i]) {
            blocks[bi].start = i;
            int end = p->sizecode;
            for (int j = i + 1; j < p->sizecode; j++) {
                if (is_start[j]) { end = j; break; }
            }
            blocks[bi].end = end;
            blocks[bi].nsucc = 0;
            blocks[bi].fall_succ = -1;
            blocks[bi].jmp_target = -1;
            bi++;
        }
    }

    /* === 步骤3: 确定每个块的后继 === */
    for (int b = 0; b < nblocks; b++) {
        int last = blocks[b].end - 1;
        int op = p->code[last] & 0x3F;
#if CFG_SHUFFLE_DEBUG
        fprintf(stderr, "  block[%d] last_idx=%d op=%d\n", b, last, op);
#endif

        if (op == 30) {  /* JMP */
            int sbx = get_sbx(p->code[last]);
            int target = last + 1 + sbx;
            /* 查找目标块 */
            {
                int tb = find_block_containing(blocks, nblocks, target);
                if (tb >= 0) {
                    blocks[b].jmp_target = tb;
                    blocks[b].succ[blocks[b].nsucc++] = tb;
                }
            }
            /* 检查是否是条件块(前一条是条件指令) */
            if (last > 0) {
                int prev_op = p->code[last - 1] & 0x3F;
                if (is_conditional(prev_op)) {
                    /* 条件块: fall-through = then分支 = 下一块 */
                    if (b + 1 < nblocks) {
                        blocks[b].fall_succ = b + 1;
                        /* 避免重复添加 */
                        if (blocks[b].succ[0] != b + 1 && blocks[b].nsucc < 2) {
                            blocks[b].succ[blocks[b].nsucc++] = b + 1;
                        }
                    }
                }
            }
            /* 无条件JMP: 无fall-through */
        } else if (op == 38 || op == 37) {  /* RETURN / TAILCALL */
            /* 无后继 */
        } else if (op == 39 || op == 42) {  /* FORLOOP / TFORLOOP */
            /* 跳转目标 = 循环体 */
            int sbx = get_sbx(p->code[last]);
            int target = last + 1 + sbx;
            {
                int tb = find_block_containing(blocks, nblocks, target);
                if (tb >= 0) {
                    blocks[b].jmp_target = tb;
                    blocks[b].succ[blocks[b].nsucc++] = tb;
                }
            }
            /* fall-through = 循环结束后 = 下一块 */
            if (b + 1 < nblocks) {
                blocks[b].fall_succ = b + 1;
                if (blocks[b].nsucc < 2) {
                    blocks[b].succ[blocks[b].nsucc++] = b + 1;
                }
            }
        } else if (op == 40) {  /* FORPREP */
            /* 总是跳转到循环体(通常是下一块) */
            int sbx = get_sbx(p->code[last]);
            int target = last + 1 + sbx;
            {
                int tb = find_block_containing(blocks, nblocks, target);
                if (tb >= 0) {
                    blocks[b].jmp_target = tb;
                    blocks[b].succ[blocks[b].nsucc++] = tb;
                }
            }
            /* 无fall-through (总是跳转) */
        } else {
            /* 非终止指令: fall-through到下一块 */
            if (b + 1 < nblocks) {
                blocks[b].fall_succ = b + 1;
                blocks[b].succ[blocks[b].nsucc++] = b + 1;
            }
        }
    }

#if CFG_SHUFFLE_DEBUG
    for (int b = 0; b < nblocks; b++) {
        fprintf(stderr, "  block[%d] [%d,%d) jmp_target=%d fall_succ=%d nsucc=%d\n",
                b, blocks[b].start, blocks[b].end, blocks[b].jmp_target,
                blocks[b].fall_succ, blocks[b].nsucc);
    }
#endif

    /* === 步骤4: 随机打乱块顺序(保留块0) === */
    int *order = (int *)malloc(sizeof(int) * nblocks);
    for (int i = 0; i < nblocks; i++) order[i] = i;
    /* Fisher-Yates shuffle on blocks 1..nblocks-1 */
    for (int i = nblocks - 1; i > 1; i--) {
        int j = 1 + (obf_rand() % i);
        int tmp = order[i]; order[i] = order[j]; order[j] = tmp;
    }

    /* === 步骤5: 计算新块起始位置 === */
    int *new_start = (int *)malloc(sizeof(int) * nblocks);
    int pos = 0;
    for (int i = 0; i < nblocks; i++) {
        int b = order[i];
        new_start[b] = pos;
        int len = blocks[b].end - blocks[b].start;
        pos += len;
        /* 如果需要插入fall-through JMP, 预留位置 */
        if (blocks[b].fall_succ >= 0) {
            int next_b = (i + 1 < nblocks) ? order[i + 1] : -1;
            if (blocks[b].fall_succ != next_b) {
                pos += 1;  /* 插入一条JMP */
            }
        }
    }
    int new_size = pos;

#if CFG_SHUFFLE_DEBUG
    fprintf(stderr, "[cfg_shuffle] new_size=%d (original %d)\n", new_size, p->sizecode);
#endif

    /* === 步骤6: 构建新指令数组 + 建立原始位置->新位置映射 === */
    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * new_size);
    int *orig_to_new = (int *)malloc(sizeof(int) * p->sizecode);
    pos = 0;
    for (int i = 0; i < nblocks; i++) {
        int b = order[i];
        int len = blocks[b].end - blocks[b].start;
        for (int j = 0; j < len; j++) {
            orig_to_new[blocks[b].start + j] = pos + j;
        }
        memcpy(new_code + pos, p->code + blocks[b].start, sizeof(unsigned int) * len);
        pos += len;

        /* 检查是否需要插入fall-through JMP */
        if (blocks[b].fall_succ >= 0) {
            int next_b = (i + 1 < nblocks) ? order[i + 1] : -1;
            if (blocks[b].fall_succ != next_b) {
                /* 插入JMP到fall_succ块 */
                int target_pos = new_start[blocks[b].fall_succ];
                int sbx = target_pos - (pos + 1);
                new_code[pos] = set_sbx(LUAC_ABC(30, 0, 0, 0), sbx);  /* JMP A=0 */
                pos += 1;
            }
        }
    }

    /* === 步骤7: 修正所有JMP的sBx (用原始位置->新位置映射) === */
    for (int i = 0; i < new_size; i++) {
        int op = new_code[i] & 0x3F;
        if (op == 30 || op == 39 || op == 40 || op == 42) {
            /* 找到这条指令在原始代码中的位置 (反向查找 orig_to_new) */
            int orig_pos = -1;
            for (int j = 0; j < p->sizecode; j++) {
                if (orig_to_new[j] == i) { orig_pos = j; break; }
            }
            if (orig_pos >= 0) {
                int orig_sbx = get_sbx(p->code[orig_pos]);
                int orig_target = orig_pos + 1 + orig_sbx;
                if (orig_target >= 0 && orig_target < p->sizecode) {
                    int new_target = orig_to_new[orig_target];
                    int new_sbx = new_target - (i + 1);
                    new_code[i] = set_sbx(new_code[i], new_sbx);
                }
            }
            /* 如果 orig_pos < 0, 这是插入的 JMP, 已在步骤6设置正确 sbx */
        }
    }
    free(orig_to_new);

    /* === 步骤8: 替换proto的code === */
    free(p->code);
    p->code = new_code;
    p->sizecode = new_size;

    /* === 递归处理子proto === */
    int sub_changes = 0;
    if (p->p) {
        for (int i = 0; i < p->sizep; i++) {
            sub_changes += cfg_shuffle_process_sub(p->p[i]);
        }
    }

    free(is_start);
    free(blocks);
    free(order);
    free(new_start);

    int changes = 1 + sub_changes;
    lua_pushinteger(L, changes);
    return 1;
}

/* 递归处理子proto(不经过Lua栈) */
static int cfg_shuffle_process_sub(luac_Proto *p) {
    if (p->sizecode < 6) return 0;

    int *is_start = (int *)calloc(p->sizecode, sizeof(int));
    is_start[0] = 1;
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (is_terminator(op)) {
            int sbx = get_sbx(p->code[i]);
            int target = i + 1 + sbx;
            if (target >= 0 && target < p->sizecode) is_start[target] = 1;
            if (i + 1 < p->sizecode) is_start[i + 1] = 1;
        }
    }

    /* Protect all inseparable instruction pairs from being split across blocks */
    protect_inseparable_regions(is_start, p->code, p->sizecode);

    int nblocks = 0;
    for (int i = 0; i < p->sizecode; i++) if (is_start[i]) nblocks++;
    if (nblocks < 3) { free(is_start); return 0; }

    Block *blocks = (Block *)malloc(sizeof(Block) * nblocks);
    int bi = 0;
    for (int i = 0; i < p->sizecode; i++) {
        if (is_start[i]) {
            blocks[bi].start = i;
            int end = p->sizecode;
            for (int j = i + 1; j < p->sizecode; j++) {
                if (is_start[j]) { end = j; break; }
            }
            blocks[bi].end = end;
            blocks[bi].nsucc = 0;
            blocks[bi].fall_succ = -1;
            blocks[bi].jmp_target = -1;
            bi++;
        }
    }

    for (int b = 0; b < nblocks; b++) {
        int last = blocks[b].end - 1;
        int op = p->code[last] & 0x3F;
        if (op == 30) {
            int sbx = get_sbx(p->code[last]);
            int target = last + 1 + sbx;
            {
                int tb = find_block_containing(blocks, nblocks, target);
                if (tb >= 0) {
                    blocks[b].jmp_target = tb;
                    blocks[b].succ[blocks[b].nsucc++] = tb;
                }
            }
            if (last > 0 && is_conditional(p->code[last - 1] & 0x3F)) {
                if (b + 1 < nblocks) {
                    blocks[b].fall_succ = b + 1;
                    if (blocks[b].succ[0] != b + 1 && blocks[b].nsucc < 2)
                        blocks[b].succ[blocks[b].nsucc++] = b + 1;
                }
            }
        } else if (op == 38 || op == 37) {
        } else if (op == 39 || op == 42) {
            int sbx = get_sbx(p->code[last]);
            int target = last + 1 + sbx;
            {
                int tb = find_block_containing(blocks, nblocks, target);
                if (tb >= 0) {
                    blocks[b].jmp_target = tb;
                    blocks[b].succ[blocks[b].nsucc++] = tb;
                }
            }
            if (b + 1 < nblocks) {
                blocks[b].fall_succ = b + 1;
                if (blocks[b].nsucc < 2) blocks[b].succ[blocks[b].nsucc++] = b + 1;
            }
        } else if (op == 40) {
            int sbx = get_sbx(p->code[last]);
            int target = last + 1 + sbx;
            {
                int tb = find_block_containing(blocks, nblocks, target);
                if (tb >= 0) {
                    blocks[b].jmp_target = tb;
                    blocks[b].succ[blocks[b].nsucc++] = tb;
                }
            }
        } else {
            if (b + 1 < nblocks) {
                blocks[b].fall_succ = b + 1;
                blocks[b].succ[blocks[b].nsucc++] = b + 1;
            }
        }
    }

    int *order = (int *)malloc(sizeof(int) * nblocks);
    for (int i = 0; i < nblocks; i++) order[i] = i;
    for (int i = nblocks - 1; i > 1; i--) {
        int j = 1 + (obf_rand() % i);
        int tmp = order[i]; order[i] = order[j]; order[j] = tmp;
    }

    int *new_start = (int *)malloc(sizeof(int) * nblocks);
    int pos = 0;
    for (int i = 0; i < nblocks; i++) {
        int b = order[i];
        new_start[b] = pos;
        pos += blocks[b].end - blocks[b].start;
        if (blocks[b].fall_succ >= 0) {
            int next_b = (i + 1 < nblocks) ? order[i + 1] : -1;
            if (blocks[b].fall_succ != next_b) pos += 1;
        }
    }
    int new_size = pos;

    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * new_size);
    int *orig_to_new = (int *)malloc(sizeof(int) * p->sizecode);
    pos = 0;
    for (int i = 0; i < nblocks; i++) {
        int b = order[i];
        int len = blocks[b].end - blocks[b].start;
        for (int j = 0; j < len; j++) {
            orig_to_new[blocks[b].start + j] = pos + j;
        }
        memcpy(new_code + pos, p->code + blocks[b].start, sizeof(unsigned int) * len);
        pos += len;
        if (blocks[b].fall_succ >= 0) {
            int next_b = (i + 1 < nblocks) ? order[i + 1] : -1;
            if (blocks[b].fall_succ != next_b) {
                int target_pos = new_start[blocks[b].fall_succ];
                int sbx = target_pos - (pos + 1);
                new_code[pos] = set_sbx(LUAC_ABC(30, 0, 0, 0), sbx);
                pos += 1;
            }
        }
    }

    for (int i = 0; i < new_size; i++) {
        int op = new_code[i] & 0x3F;
        if (op == 30 || op == 39 || op == 40 || op == 42) {
            int orig_pos = -1;
            for (int j = 0; j < p->sizecode; j++) {
                if (orig_to_new[j] == i) { orig_pos = j; break; }
            }
            if (orig_pos >= 0) {
                int orig_sbx = get_sbx(p->code[orig_pos]);
                int orig_target = orig_pos + 1 + orig_sbx;
                if (orig_target >= 0 && orig_target < p->sizecode) {
                    int new_target = orig_to_new[orig_target];
                    new_code[i] = set_sbx(new_code[i], new_target - (i + 1));
                }
            }
        }
    }
    free(orig_to_new);

    free(p->code);
    p->code = new_code;
    p->sizecode = new_size;

    int sub = 0;
    if (p->p) for (int i = 0; i < p->sizep; i++) sub += cfg_shuffle_process_sub(p->p[i]);

    free(is_start); free(blocks); free(order); free(new_start);
    return 1 + sub;
}
