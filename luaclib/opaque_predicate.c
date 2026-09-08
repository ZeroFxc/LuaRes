/*
** opaque_predicate.c - Multi-pattern opaque predicate with dead code blocks
**
** 8 patterns (random):
**  0: LOADK 0 + LOADK 0 + LT(0<0=false) + JMP + dead   (always-false)
**  1: LOADK N + MUL(r,r) + LT(r<0=false) + JMP + dead  (always-false, x*x<0)
**  2: LOADK N + BXOR(r,r) + EQ(r==0=true) + JMP(dead)  (always-true, x^x==0)
**  3: LOADK N + BAND(r,r) + EQ(r==r=true) + JMP(dead)  (always-true, x&x==x)
**  4: LOADK N + BNOT+BNOT + EQ(r==r=true) + JMP(dead)  (always-true, ~~x==x)
**  5: LOADK N + ADD(r,1) + LT(r<r+1=true) + JMP(dead)  (always-true, x<x+1)
**  6: LOADK N + IDIV(r,1) + EQ(r==r=true) + JMP(dead)  (always-true, x//1==x)
**  7: LOADK N + MUL(r,r) + LE(0<=r=true) + JMP(dead)   (always-true, 0<=x*x)
**
** Always-false patterns (0,1): JMP always taken → dead code skipped
** Always-true patterns (2-7): JMP never taken → JMP itself is dead
*/
#include <time.h>
#include "obf_util.h"

#define CONDITION_OPS(op) ((op)==LUAC_OP_EQ||(op)==LUAC_OP_LT||(op)==LUAC_OP_LE||(op)==LUAC_OP_TEST||(op)==LUAC_OP_TESTSET||(op)==LUAC_OP_LOADKX||(op)==LUAC_OP_TFORCALL||(op)==LUAC_OP_CLOSURE)

static unsigned int random_dead_insn(luac_Proto *p, int r1, int r2) {
    /* 生成安全的死指令：只使用 MOVE/LOADBOOL/LOADK(数字)，不做算术位运算，
       避免对 nil/function/string 等非数字值操作导致运行时错误 */
    int r = obf_rand() % 5;
    int kc = 0;
    for (int tries = 0; tries < p->sizek; tries++) {
        int candidate = (int)(obf_rand() % p->sizek);
        if (p->k_tag[candidate] == LUA_TNUMFLT || p->k_tag[candidate] == LUA_TNUMINT) { kc = candidate; break; }
    }
    switch (r) {
        case 0: return LUAC_ABC(LUAC_OP_MOVE, r1, r2, 0);
        case 1: return LUAC_ABC(LUAC_OP_MOVE, r2, r1, 0);
        case 2: return LUAC_ABC(LUAC_OP_LOADBOOL, r1, obf_rand() % 2, 0);
        case 3: return LUAC_ABC(LUAC_OP_LOADBOOL, r2, obf_rand() % 2, 0);
        default: return LUAC_ABx(LUAC_OP_LOADK, r1, kc);
    }
}

static int get_num_const(luac_Proto *p, double val) {
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TNUMFLT || p->k_tag[i] == LUA_TNUMINT) && p->k_num[i] == val) return i;
    }
    return obf_add_k_number(p, val);
}

/* emit LOADK or LOADKX+EXTRAARG for constant index (handles >255) */
static int emit_loadk(unsigned int *buf, int reg, int kidx) {
    if (kidx <= 255) {
        buf[0] = LUAC_ABx(LUAC_OP_LOADK, reg, kidx);
        return 1;
    } else {
        buf[0] = LUAC_ABx(LUAC_OP_LOADKX, reg, 0);
        buf[1] = LUAC_Ax(LUAC_OP_EXTRAARG, kidx);
        return 2;
    }
}

/* 在指定位置插入不透明谓词块，返回插入长度 */
static int insert_predicate_at(luac_Proto *p, int pos) {
    /* scan actual highest register used in code (maxstacksize may be inaccurate) */
    int actual_max = (int)p->maxstacksize - 1;
    if (actual_max < 0) actual_max = 0;
    for (int _si = 0; _si < p->sizecode; _si++) {
        unsigned int _ins = p->code[_si];
        int _op = _ins & 0x3F;
        int _a = (_ins >> 6) & 0xFF;
        int _b = (_ins >> 23) & 0x1FF;
        int _c = (_ins >> 14) & 0x1FF;
        if (_a > actual_max) actual_max = _a;
        switch (_op) {
            case 0: case 3: case 4: case 5: case 9: case 25: case 26: case 27: case 28: case 34: case 35:
                if (_b < 256 && _b > actual_max) actual_max = _b; break;
            case 6: case 7: case 8: case 10: case 11: case 13: case 14: case 15: case 16: case 17:
            case 18: case 19: case 20: case 21: case 22: case 23: case 24: case 31: case 32: case 33:
                if (_b < 256 && _b > actual_max) actual_max = _b;
                if (_c < 256 && _c > actual_max) actual_max = _c; break;
            case 12: if (_a + 1 > actual_max) actual_max = _a + 1;
                if (_b < 256 && _b > actual_max) actual_max = _b;
                if (_c < 256 && _c > actual_max) actual_max = _c; break;
            case 29: if (_b < 256 && _b > actual_max) actual_max = _b;
                if (_c < 256 && _c > actual_max) actual_max = _c; break;
            case 36: case 37:
                if (_b > 0 && _b < 256 && _a + _b - 1 > actual_max) actual_max = _a + _b - 1; break;
            case 38: if (_b > 0 && _b < 256 && _a + _b - 2 > actual_max) actual_max = _a + _b - 2; break;
            case 39: case 40: case 41: if (_a + 3 > actual_max) actual_max = _a + 3; break;
            case 42: if (_a + 2 > actual_max) actual_max = _a + 2; break;
            case 43: if (_b > 0 && _b < 256 && _a + _b > actual_max) actual_max = _a + _b; break;
            case 45: if (_b > 0 && _b < 256 && _a + _b - 2 > actual_max) actual_max = _a + _b - 2; break;
            default: break;
        }
    }
    int r1 = actual_max + 1;
    int r2 = actual_max + 2;
    int r3 = actual_max + 3;
    if (r3 + 1 > 255) return 0;  /* register overflow */
    obf_ensure_stack(p, r3 + 1);

    int pattern = obf_rand() % 8;
    int zero_idx = get_num_const(p, 0.0);
    int one_idx = get_num_const(p, 1.0);
    /* 随机一个非零整数作为谓词的"种子" */
    int seed_val = (int)(obf_rand() % 2000) - 1000;
    if (seed_val == 0) seed_val = 42;
    int seed_idx = get_num_const(p, (double)seed_val);

#ifdef OPAQUE_DEBUG
    fprintf(stderr, "[OP] pos=%d pat=%d r1=%d r2=%d zero=%d one=%d seed=%d(%d) sizek=%d maxstack=%d\n",
        pos, pattern, r1, r2, zero_idx, one_idx, seed_idx, seed_val, p->sizek, p->maxstacksize);
    for (int _di = 0; _di < p->sizek && _di < 5; _di++) {
        const char *_tn = "?";
        switch (p->k_tag[_di]) { case 0: _tn="nil"; break; case 1: _tn="bool"; break; case 3: _tn="flt"; break; case 19: _tn="int"; break; case 4: case 20: _tn="str"; break; }
        fprintf(stderr, "  k[%d] tag=%d(%s)", _di, p->k_tag[_di], _tn);
        if (p->k_tag[_di] == 19) fprintf(stderr, " val=%lld", (long long)p->k_num[_di]);
        else if (p->k_tag[_di] == 3) fprintf(stderr, " val=%g", p->k_num[_di]);
        else if (p->k_tag[_di] == 4 || p->k_tag[_di] == 20) fprintf(stderr, " val=%s", p->k_str[_di] ? p->k_str[_di] : "(null)");
        fprintf(stderr, "\n");
    }
#endif

    int dead_len = 4 + (int)(obf_rand() % 10); /* 4-13 条死指令 */
    int prefix = 0;
    unsigned int prefix_buf[12];

    /* All patterns use register-only comparisons to avoid C/B field overflow
       when constant index > 255 (idx+256 > 511 overflows 9-bit field) */
    switch (pattern) {
        case 0: /* 0<0 always-false */
            prefix += emit_loadk(&prefix_buf[prefix], r2, zero_idx);
            prefix += emit_loadk(&prefix_buf[prefix], r3, zero_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_LT, 0, r2, r3);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 1: /* x*x<0 always-false */
            prefix += emit_loadk(&prefix_buf[prefix], r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_MUL, r1, r1, r1);
            prefix += emit_loadk(&prefix_buf[prefix], r2, zero_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_LT, 0, r1, r2);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 2: /* x^x==0 always-true */
            prefix += emit_loadk(&prefix_buf[prefix], r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_BXOR, r1, r1, r1);
            prefix += emit_loadk(&prefix_buf[prefix], r2, zero_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_EQ, 1, r1, r2);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 3: /* x&x==x always-true */
            prefix += emit_loadk(&prefix_buf[prefix], r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_BAND, r1, r1, r1);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_EQ, 1, r1, r1);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 4: /* ~~x==x always-true */
            prefix += emit_loadk(&prefix_buf[prefix], r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_BNOT, r1, r1, 0);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_BNOT, r1, r1, 0);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_EQ, 1, r1, r1);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 5: /* x<x+1 always-true */
            prefix += emit_loadk(&prefix_buf[prefix], r1, seed_idx);
            prefix += emit_loadk(&prefix_buf[prefix], r3, one_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_ADD, r2, r1, r3);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_LT, 1, r1, r2);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 6: /* x//1==x always-true */
            prefix += emit_loadk(&prefix_buf[prefix], r1, seed_idx);
            prefix += emit_loadk(&prefix_buf[prefix], r3, one_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_IDIV, r2, r1, r3);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_EQ, 1, r2, r1);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
        case 7: /* 0<=x*x always-true */
            prefix += emit_loadk(&prefix_buf[prefix], r1, seed_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_MUL, r1, r1, r1);
            prefix += emit_loadk(&prefix_buf[prefix], r2, zero_idx);
            prefix_buf[prefix++] = LUAC_ABC(LUAC_OP_LE, 1, r2, r1);
            prefix_buf[prefix++] = LUAC_AsBx(LUAC_OP_JMP, 0, dead_len);
            break;
    }

    int insert_len = prefix + dead_len;
#ifdef OPAQUE_DEBUG
    {
        static const char *opn4[] = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"};
        fprintf(stderr, "[OP-INS] before pos=%d insert_len=%d\n", pos, insert_len);
        for (int _di = pos - 3; _di <= pos + 3 && _di < p->sizecode; _di++) {
            if (_di < 0) continue;
            unsigned int _ins = p->code[_di];
            int _op = _ins & 0x3F;
            fprintf(stderr, "  [%d] %s A=%d B=%d C=%d%s\n", _di,
                _op < 47 ? opn4[_op] : "?",
                (_ins >> 6) & 0xFF, (_ins >> 23) & 0x1FF, (_ins >> 14) & 0x1FF,
                _di == pos ? " <-- INSERT HERE" : "");
        }
    }
#endif
    p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + insert_len));
    memmove(&p->code[pos + insert_len], &p->code[pos],
            sizeof(unsigned int) * (p->sizecode - pos));
    memcpy(&p->code[pos], prefix_buf, sizeof(unsigned int) * prefix);
    p->code[pos + prefix] = LUAC_ABx(LUAC_OP_LOADK, r1, zero_idx <= 255 ? zero_idx : 0);
    p->code[pos + prefix + 1] = LUAC_ABx(LUAC_OP_LOADK, r2, zero_idx <= 255 ? zero_idx : 0);
    for (int i = 2; i < dead_len; i++)
        p->code[pos + prefix + i] = random_dead_insn(p, r1, r2);
    p->sizecode += insert_len;

    /* 调整跳转：插入位置 pos (0-based) = pos+1 (1-based) */
    obf_adjust_jumps_insert(p->code, p->sizecode, pos + 1, insert_len);

#ifdef OPAQUE_DEBUG
    /* validate all jumps */
    for (int _vi = 0; _vi < p->sizecode; _vi++) {
        int _op = p->code[_vi] & 0x3F;
        if (_op == LUAC_OP_JMP || _op == LUAC_OP_FORLOOP || _op == LUAC_OP_FORPREP || _op == LUAC_OP_TFORLOOP) {
            int _sbx = (int)((p->code[_vi] >> 14) & 0x3FFFF) - 131071;
            int _tgt = _vi + _sbx + 1;
            if (_tgt < 0 || _tgt >= p->sizecode) {
                fprintf(stderr, "[OP-BADJUMP] idx=%d op=%d sbx=%d target=%d (range 0-%d)\n",
                    _vi, _op, _sbx, _tgt, p->sizecode - 1);
            }
            /* check if target lands inside this predicate block */
            if (_tgt >= pos && _tgt < pos + insert_len && _vi < pos) {
                static const char *opn5[] = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"};
                fprintf(stderr, "[OP-TGTINBLOCK] jump idx=%d (%s) sbx=%d target=%d lands in predicate block [%d,%d]\n",
                    _vi, _op < 47 ? opn5[_op] : "?", _sbx, _tgt, pos, pos + insert_len - 1);
            }
        }
    }
#endif

    return insert_len;
}

static int is_safe_pos(luac_Proto *p, int pos) {
    if (pos <= 0 || pos >= p->sizecode) return 0;
    /* 不能在条件/CLOSURE 指令后插入（下一条必须是 JMP/MOV） */
    if (CONDITION_OPS(p->code[pos - 1] & 0x3F)) return 0;
    /* SETLIST C==0 后必须跟 EXTRAARG */
    if ((p->code[pos - 1] & 0x3F) == LUAC_OP_SETLIST && ((p->code[pos - 1] >> 14) & 0x1FF) == 0) return 0;
    /* 不能在 RETURN/EXTRAARG 位置插入 */
    if ((p->code[pos] & 0x3F) == LUAC_OP_RETURN) return 0;
    if ((p->code[pos] & 0x3F) == LUAC_OP_EXTRAARG) return 0;
    return 1;
}

static void inject_function(luac_Proto *p, int count) {
    if (!p->code || p->sizecode < 4 || count <= 0) return;

    int injected = 0;
    int attempts = 0;
    while (injected < count && attempts < count * 15) {
        attempts++;
        int pos = 1 + (int)(obf_rand() % (p->sizecode - 2));
        if (!is_safe_pos(p, pos)) continue;
        if (insert_predicate_at(p, pos) > 0) injected++;
    }

    /* 函数头也插一个 */
    if (p->sizecode > 4) {
        insert_predicate_at(p, 0);
    }

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; }
    p->sizelineinfo = 0;
}

int opaque_predicate_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    obf_invalidate_all_caches(L, p);

    int count = 8;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "count");
        if (lua_isnumber(L, -1)) count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }

    inject_function(p, count);

    if (p->p) {
        for (int i = 0; i < p->sizep; i++) {
            inject_function(p->p[i], count > 4 ? count / 2 : 2);
        }
    }

    lua_pushinteger(L, 1);
    return 1;
}
