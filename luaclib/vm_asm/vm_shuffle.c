/*
** vm_shuffle.c - VM 内部名空间重映射（vm_reg_shuffle / vm_const_shuffle）
**
** vm_reg_shuffle:  自包含 VM 载荷里寄存器编号打乱（解释器内部名空间乱序）。
**                  关键约束：CALL/TAILCALL/SETLIST/VARARG/RETURN/SELF/TFORCALL
**                  的 A 是"连续寄存器区"锚点（解释器按 A+k 隐式展开），任意
**                  permutation 会破坏区一致性 → 先做锚定扫描，锚定寄存器保持
**                  原位（恒等映射），仅非锚定寄存器参与 Fisher-Yates 置换。
**                  upvalue instack=1 的 idx 引父栈帧寄存器，需按父 proto 的
**                  reg_map 同步 remap。
**
** vm_const_shuffle: VM 常量池表顺序打乱 + 载荷常量索引（LOADK Bx / EXTRAARG
**                  Ax / RK B/C）同步 remap。RK 常量索引必须 <256 才能编码，
**                  因此 kmap 对 [0,min(sizek,256)) 与 [256,sizek) 分两段独立
**                  置换，保证 RK 索引 remap 后仍 <256。
**
** 与 vm_dispatch_shuffle 同思路：模块只设全局（seed），vm_embed_generate
** 序列化时应用。vm_embed 最后执行，故只影响最终自包含 VM 输出。
*/
#include "vm_asm.h"
#include "obf_util.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

/* ---------- global shuffle configuration ---------- */
static unsigned int g_rs_seed = 0; static int g_rs_on = 0;
static unsigned int g_cs_seed = 0; static int g_cs_on = 0;

void vm_reg_shuffle_set(unsigned int seed) { g_rs_seed = seed; g_rs_on = 1; }
void vm_reg_shuffle_reset(void) { g_rs_seed = 0; g_rs_on = 0; }
int vm_reg_shuffle_enabled(void) { return g_rs_on; }
unsigned int vm_reg_shuffle_get_seed(void) { return g_rs_seed; }

void vm_const_shuffle_set(unsigned int seed) { g_cs_seed = seed; g_cs_on = 1; }
void vm_const_shuffle_reset(void) { g_cs_seed = 0; g_cs_on = 0; }
int vm_const_shuffle_enabled(void) { return g_cs_on; }
unsigned int vm_const_shuffle_get_seed(void) { return g_cs_seed; }

/* ---------- generic permutation (Fisher-Yates, deterministic by seed) ---------- */
int *vm_make_perm(unsigned int seed, int n) {
    int *inv = malloc(n * sizeof(int));
    int *map = malloc(n * sizeof(int));
    if (!inv || !map) { free(inv); free(map); return NULL; }
    for (int i = 0; i < n; i++) inv[i] = i;
    vm_srand(seed);
    for (int i = n - 1; i > 0; i--) {
        int j = (int)(vm_rand() % (unsigned)(i + 1));
        int t = inv[i]; inv[i] = inv[j]; inv[j] = t;
    }
    for (int i = 0; i < n; i++) map[inv[i]] = i;
    free(inv);
    return map;
}

/* const map: [0,min(sizek,256)) 与 [256,sizek) 分段独立置换，RK(<256) 保持可编码 */
int *vm_make_kmap(unsigned int seed, int sizek) {
    int *map = malloc(sizek * sizeof(int));
    if (!map) return NULL;
    for (int i = 0; i < sizek; i++) map[i] = i;
    int n1 = sizek < 256 ? sizek : 256;
    if (n1 > 1) {
        int *p = vm_make_perm(seed, n1);
        if (p) { for (int i = 0; i < n1; i++) map[i] = p[i]; free(p); }
    }
    if (sizek > 256) {
        int n2 = sizek - 256;
        int *p = vm_make_perm(seed ^ 0x9E3779B9u, n2);
        if (p) { for (int i = 0; i < n2; i++) map[256 + i] = 256 + p[i]; free(p); }
    }
    return map;
}

/* ---------- per-op register-field semantics (Lua 5.3 + andlua ext) ----------
   A_REMAP : A 字段是寄存器（1=可 remap）
   B/C_REMAP: 0=非寄存器（数量/标志/upvalue索引/未知扩展），1=寄存器/RK（<256 视为寄存器，>=256 为 RK 常量），2=该格式无此字段（iABx/iAsBx/iAx） */
static const unsigned char A_REMAP[54] = {
    1,1,1,1,1,1,1,1,0,0,1,1,1,            /*  0-12 MOVE..SELF (8 SETTABUP A 是 upvalue 索引, 9 SETUPVAL A 是 upvalue 索引) */
    1,1,1,1,1,1,1,1,1,1,1,1,              /* 13-24 ADD..SHR */
    1,1,1,1,1,                             /* 25-29 UNM..CONCAT */
    0,1,1,1,1,1,1,1,1,1,                   /* 30-39 JMP..FORLOOP (30 JMP A 无意义, 31-33 EQ/LT/LE A 是 RK, 34 TEST A 是寄存器, 35 TESTSET A 是寄存器) */
    1,1,1,1,1,                             /* 40-44 FORPREP..CLOSURE */
    1,0,                                    /* 45 VARARG, 46 EXTRAARG(iAx) */
    1,1,1,1,1,1,1                          /* 47-53 andlua 扩展 */
};
static const unsigned char B_REMAP[54] = {
    1,2,2,0,0,0,0,1,1,1,1,0,1,             /*  0-12 MOVE..SELF (SELF B=对象寄存器, 可remap) */
    1,1,1,1,1,1,1,1,1,1,1,1,1,             /* 13-25 */
    1,1,1,1,2,2,2,2,1,1,0,0,0,             /* 26-38 BNOT..RETURN (30 JMP无B, 31-33 EQ/LT/LE B=RK, 34 TEST B=寄存器, 35 TESTSET B=寄存器, 36/37 CALL B=参数数量, 38 RETURN B=返回值数量) */
    2,2,0,2,0,2,0,2,0,0,0,0,0,0,0          /* 39-53 */
};
static const unsigned char C_REMAP[54] = {
    0,2,2,0,0,0,1,1,1,0,1,0,1,             /*  0-12 */
    1,1,1,1,1,1,1,1,1,1,1,1,0,             /* 13-25 */
    0,0,0,1,2,2,2,2,0,0,0,0,2,             /* 26-38 BNOT..RETURN (30 JMP无C, 31-33 EQ/LT/LE C=RK, 34/35 TEST/TESTSET C=条件, 36/37 CALL C=返回值数量, 38 RETURN无C) */
    2,2,0,2,0,2,0,2,0,0,0,0,0,0,0          /* 39-53 */
};

/* ---------- 锚定扫描：连续寄存器区不参与置换 ---------- */
void vm_reg_anchor_scan(const unsigned int *code, int ncode,
                        unsigned char *anchored, int maxstack, int numparams) {
    memset(anchored, 0, (size_t)maxstack);
    /* 调用约定：execute 进入函数时参数从 R[0] 起按原编号放置，参数区必须锚定 */
    for (int i = 0; i < numparams && i < maxstack; i++) anchored[i] = 1;
    for (int i = 0; i < ncode; i++) {
        unsigned int ins = code[i];
        unsigned int op = ins & 0x3F;
        unsigned int a = (ins >> 6) & 0xFF;
        unsigned int b = (ins >> 23) & 0x1FF;
        unsigned int c = (ins >> 14) & 0x1FF;
        unsigned int lo = 0, hi = 0;
        int scan = 0;
        switch (op) {
            case 30: /* JMP A sBx: A!=0 时关闭 idx>=A-1 的 upvalue。
                           A 是 upvalue 列表索引不是寄存器编号，不能用 lo=a-1 标记寄存器范围。
                           instack=1 upvalue 引用的寄存器已由调用方（vm_embed.c）单独锚定。 */
                break;
            case 4: /* LOADNIL A B: R[A..B]=nil; B<A 时 Lua 语义只 R[A]=nil */
                lo = a; hi = ((int)b >= (int)a) ? (b + 1) : (a + 1); scan = 1; break;
            case 29: /* CONCAT A B C: 读 R[B..C] */
                lo = b; hi = c + 1; scan = 1; break;
            case 12: /* SELF A B C: 写 R[A], R[A+1] */
                lo = a; hi = a + 2; scan = 1; break;
            case 36: case 37: /* CALL/TAILCALL: 读 R[A..A+B-1] 写 R[A..A+C-2] */
                if (b == 0 || c == 0) { lo = a; hi = maxstack; }
                else { lo = a; hi = a + ((b > c) ? b : c); } /* 保守含 B-1 与 C-2 区 */
                scan = 1; break;
            case 38: /* RETURN A B: 读 R[A..A+B-1], B=0 多变 */
                lo = a; hi = (b == 0) ? (unsigned int)maxstack : a + b;
                scan = 1; break;
            case 39: case 40: /* FORLOOP/FORPREP: 控制 R[A..A+2] + 循环变量副本 R[A+3] */
                lo = a; hi = a + 4; scan = 1; break;
            case 42: /* TFORLOOP A sBx: 控制 R[A..A+3] (迭代函数+状态+控制变量+返回值) */
                lo = a; hi = a + 4; scan = 1; break;
            case 41: /* TFORCALL A C: 控制 R[A..A+2] + 返回值 R[A+3..A+3+C-1] */
                lo = a; hi = a + 3 + ((c > 0) ? (int)c : 1); scan = 1; break;
            case 43: /* SETLIST A B C: 读表 R[A] + 元素 R[A+1..A+B], B=0 元素数在 EXTRAARG */
                lo = a; hi = (b == 0) ? (unsigned int)maxstack : a + b + 1;
                scan = 1; break;
            case 45: /* VARARG A B: 写 R[A..A+B-2], B=0 多变 */
                lo = a; hi = (b == 0) ? (unsigned int)maxstack : a + b;
                scan = 1; break;
            default: break;
        }
        if (scan) {
            if (hi > (unsigned int)maxstack) hi = (unsigned int)maxstack;
            for (unsigned int k = lo; k < hi; k++) anchored[k] = 1;
        }
        /* upvalue 相关指令的 A 寄存器锚定：
           GETUPVAL(5) A=目标寄存器, GETTABUP(6) A=目标寄存器 → 锚定
           SETUPVAL(9) A=upvalue索引, SETTABUP(8) A=upvalue索引 → 不锚定 */
        if (op == 5 || op == 6) { /* GETUPVAL, GETTABUP */
            if (a < maxstack) anchored[a] = 1;
        }
        /* CLOSURE 后 upvalue 设置区：CLOSURE A 后面可能跟 MOVE/GETUPVAL/GETTABUP 设置 upvalue，
           这些指令的 A 寄存器与 CLOSURE 的 A 配合，必须锚定保持一致 */
        if (op == 44) { /* CLOSURE */
            if (a < maxstack) anchored[a] = 1;
            for (int j = i + 1; j < ncode && j < i + 8; j++) {
                unsigned int nop = code[j] & 0x3F;
                if (nop == 0 || nop == 5 || nop == 6) { /* MOVE, GETUPVAL, GETTABUP */
                    unsigned int na = (code[j] >> 6) & 0xFF;
                    if (na < maxstack) anchored[na] = 1;
                } else {
                    break;
                }
            }
        }
    }
}

/* reg map：锚定寄存器恒等，非锚定按 seed 置换 */
int *vm_make_regmap(unsigned int seed, const unsigned char *anchored, int maxstack) {
    int *map = malloc(maxstack * sizeof(int));
    int *free_list = malloc(maxstack * sizeof(int));
    if (!map || !free_list) { free(map); free(free_list); return NULL; }
    for (int i = 0; i < maxstack; i++) map[i] = i;  /* 锚定槽恒等（必须初始化） */
    int nfree = 0;
    for (int i = 0; i < maxstack; i++) {
        if (!anchored[i]) free_list[nfree++] = i;
    }
    if (nfree > 1) {
        int *p = vm_make_perm(seed, nfree);
        if (p) {
            for (int i = 0; i < nfree; i++) map[free_list[i]] = free_list[p[i]];
            free(p);
        }
    }
    free(free_list);
    return map;
}

/* ---------- 应用 remap 到解码后的字段 ---------- */
void vm_shuffle_fields(int op, int *a, int *b, int *c, int *bx,
                       const int *reg_map, int maxstack,
                       const int *k_map, int sizek) {
    if (reg_map && maxstack > 0) {
#if VM_SHUFFLE_DEBUG
        int dbg_a_old = *a, dbg_b_old = *b, dbg_c_old = *c;
        int dbg_hit = 0;
#endif
        /* A 字段：EQ/LT/LE (31/32/33) 的 A==0 表示比较顶部栈，不 remap */
        if (A_REMAP[op] && *a < maxstack && !((op == 31 || op == 32 || op == 33) && *a == 0)) {
            *a = reg_map[*a];
#if VM_SHUFFLE_DEBUG
            if (dbg_a_old == 1) dbg_hit = 1;
#endif
        }
        /* B_REMAP: 1=寄存器/RK, 2=该格式无此字段(iABx/iAsBx)，不remap */
        if (B_REMAP[op] == 1 && *b < 256 && *b < maxstack) {
            *b = reg_map[*b];
#if VM_SHUFFLE_DEBUG
            if (dbg_b_old == 1) dbg_hit = 1;
#endif
        }
        if (C_REMAP[op] == 1 && *c < 256 && *c < maxstack) {
            *c = reg_map[*c];
#if VM_SHUFFLE_DEBUG
            if (dbg_c_old == 1) dbg_hit = 1;
#endif
        }
#if VM_SHUFFLE_DEBUG
        if (dbg_hit) {
            fprintf(stderr, "[VM_REG_DBG] op=%d A:%d->%d(AR=%d) B:%d->%d(BR=%d) C:%d->%d(CR=%d) ms=%d\n",
                    op, dbg_a_old, *a, A_REMAP[op], dbg_b_old, *b, B_REMAP[op], dbg_c_old, *c, C_REMAP[op], maxstack);
        }
#endif
    }
    if (k_map && sizek > 0) {
        if (op == 1 && *bx < sizek) *bx = k_map[*bx];        /* LOADK */
        else if (op == 46 && *bx < sizek) *bx = k_map[*bx];  /* EXTRAARG (Ax) */
        else {
            /* RK 字段的常量部分也需要 remap */
            if (B_REMAP[op] == 1 && *b >= 256) { int ki = *b - 256; if (ki < sizek) *b = 256 + k_map[ki]; }
            if (C_REMAP[op] == 1 && *c >= 256) { int ki = *c - 256; if (ki < sizek) *c = 256 + k_map[ki]; }
        }
    }
}

/* ---------- Lua 入口（与 vm_dispatch_shuffle_c 同模式：设全局，seed=0 随机） ---------- */
static int vm_reg_shuffle_c(lua_State *L) {
    unsigned int seed = 0;
    int has_seed = 0;
    if (lua_gettop(L) >= 1 && lua_istable(L, 1)) {
        lua_getfield(L, 1, "seed");
        if (lua_isnumber(L, -1)) { seed = (unsigned int)lua_tointeger(L, -1); has_seed = 1; }
        lua_pop(L, 1);
    }
    if (has_seed && seed > 0) {
        vm_reg_shuffle_set(seed);
    } else if (!g_rs_on) {
        vm_reg_shuffle_set((unsigned int)time(NULL));
    }
    return 0;
}
static int vm_const_shuffle_c(lua_State *L) {
    unsigned int seed = 0;
    int has_seed = 0;
    if (lua_gettop(L) >= 1 && lua_istable(L, 1)) {
        lua_getfield(L, 1, "seed");
        if (lua_isnumber(L, -1)) { seed = (unsigned int)lua_tointeger(L, -1); has_seed = 1; }
        lua_pop(L, 1);
    }
    if (has_seed && seed > 0) {
        vm_const_shuffle_set(seed);
    } else if (!g_cs_on) {
        vm_const_shuffle_set((unsigned int)time(NULL));
    }
    return 0;
}

/* 注册（由 obf_register.c 调用） */
int vm_shuffle_register(lua_State *L) {
    lua_pushcfunction(L, vm_reg_shuffle_c);
    lua_setfield(L, -2, "vm_reg_shuffle_c");
    lua_pushcfunction(L, vm_const_shuffle_c);
    lua_setfield(L, -2, "vm_const_shuffle_c");
    return 0;
}
