/*
** exception_flow.c - Exception-Driven Control Flow
**
** Requires luac_flatten to run first.  Replaces selected state transitions
** (LOADK state_reg + JMP to dispatcher) with a pcall/error mechanism:
**
**   CLOSURE Rf, subproto       ; subproto = function() error(code) end
**   GETUPVAL 0,0               ; (consumed by CLOSURE — sets _ENV upvalue)
**   GETTABUP Rp, 0, K("pcall")
**   MOVE Rp+1, Rf
**   CALL Rp, 2, 3              ; ok, code = pcall(Rf)  ->  false, state_id
**   MOVE state_reg, Rp+1
**   JMP dispatcher
**
** The state id is never stored via LOADK in the parent — it travels as an
** error object through pcall.  Static CFG analysis sees a function call
** returning arbitrary data, not a direct state transition.
*/
#include <stdlib.h>
#include <string.h>
#include "obf_util.h"

#ifndef EXCFLOW_DEBUG
#define EXCFLOW_DEBUG 0
#endif
#if EXCFLOW_DEBUG
#include <stdio.h>
#define EDBG(...) fprintf(stderr, __VA_ARGS__)
#else
#define EDBG(...)
#endif

/* ---- find_state_reg ---- */
static int find_state_reg(luac_Proto *p) {
    unsigned char *is_jmp_target = (unsigned char *)calloc(p->sizecode + 1, 1);
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_JMP || op == LUAC_OP_FORLOOP || op == LUAC_OP_FORPREP ||
            op == LUAC_OP_TFORLOOP) {
            int sbx = (int)(p->code[i] >> 14) - 131071;
            int target = i + 1 + sbx;
            if (target >= 0 && target <= p->sizecode) is_jmp_target[target] = 1;
        }
    }
    int eq_counts[256] = {0};
    int loadk_at_target[256] = {0};
    for (int i = 0; i < p->sizecode; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_EQ) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (a == 1 && b < 256 && c >= 256 &&
                i + 1 < p->sizecode && (p->code[i+1] & 0x3F) == LUAC_OP_JMP)
                eq_counts[b]++;
        } else if (op == LUAC_OP_LOADK) {
            int a = (p->code[i] >> 6) & 0xFF;
            int bx = (p->code[i] >> 14) & 0x3FFFF;
            if (a < 256 && is_jmp_target[i] && bx < p->sizek &&
                (p->k_tag[bx] == LUA_TNUMINT ||
                 (p->k_tag[bx] == LUA_TNUMFLT && p->k_num[bx] == (long long)p->k_num[bx])))
                loadk_at_target[a]++;
        }
    }
    free(is_jmp_target);
    int best = -1, best_count = 0;
    for (int i = 0; i < 256; i++) {
        if (eq_counts[i] >= 2 && loadk_at_target[i] >= 2 && eq_counts[i] > best_count) {
            best_count = eq_counts[i]; best = i;
        }
    }
    return best;
}

static int get_string_const_idx(luac_Proto *p, const char *s) {
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TSTRING && p->k_str[i] &&
            strcmp(p->k_str[i], s) == 0) return i;
    }
    return obf_add_k_string(p, s, strlen(s));
}

/* create a sub-proto: function(err) err(code) end — error fn passed as arg */
static luac_Proto *create_error_subproto(long long code) {
    luac_Proto *sp = (luac_Proto *)calloc(1, sizeof(luac_Proto));
    sp->sizecode = 3;
    sp->code = (unsigned int *)malloc(sizeof(unsigned int) * 3);
    /* LOADK R1, K(0)=code */
    sp->code[0] = LUAC_ABx(LUAC_OP_LOADK, 1, 0);
    /* CALL R0, 2, 1 — err(code), R0 is the error function passed as arg */
    sp->code[1] = LUAC_ABC(LUAC_OP_CALL, 0, 2, 1);
    /* RETURN R0, 1 — unreachable */
    sp->code[2] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);

    sp->sizek = 1;
    sp->k_tag = (int *)malloc(sizeof(int) * 1);
    sp->k_str = (char **)malloc(sizeof(char *) * 1);
    sp->k_str_len = (int *)malloc(sizeof(int) * 1);
    sp->k_num = (double *)malloc(sizeof(double) * 1);
    sp->k_int = (long long *)malloc(sizeof(long long) * 1);
    sp->k_bool = (int *)malloc(sizeof(int) * 1);
    memset(sp->k_str, 0, sizeof(char *) * 1);

    sp->k_tag[0] = LUA_TNUMINT;
    sp->k_num[0] = (double)code;
    sp->k_int[0] = code;

    sp->numparams = 1;
    sp->is_vararg = 0;
    sp->maxstacksize = 2;
    sp->sizep = 0;
    sp->p = NULL;
    sp->sizeupvalues = 0;
    sp->upval_name = NULL;
    sp->upval_name_len = NULL;
    sp->upval_instack = NULL;
    sp->upval_idx = NULL;
    sp->lineinfo = NULL;
    sp->sizelineinfo = 0;
    sp->sizelocvars = 0;
    sp->locvar_name = NULL;
    sp->locvar_name_len = NULL;
    sp->locvar_startpc = NULL;
    sp->locvar_endpc = NULL;
    sp->source = NULL;
    sp->source_len = 0;
    sp->linedefined = 0;
    sp->lastlinedefined = 0;
    /* cache refs must be LUA_NOREF */
    sp->code_tbl = LUA_NOREF;
    sp->k_tbl = LUA_NOREF;
    sp->p_tbl = LUA_NOREF;
    sp->lineinfo_tbl = LUA_NOREF;
    sp->locvars_tbl = LUA_NOREF;
    sp->upvalues_tbl = LUA_NOREF;
    return sp;
}

static void exception_flow_function(luac_Proto *p) {
    if (!p->code || p->sizecode < 10) { EDBG("[excflow] skip: sizecode=%d\n", p->sizecode); return; }
    int n = p->sizecode;

    int state_reg = find_state_reg(p);
    if (state_reg < 0) { EDBG("[excflow] skip: state_reg not found (n=%d)\n", n); return; }

    /* locate dispatcher start */
    int disp_start = -1;
    for (int i = 0; i < n; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_EQ) {
            int a = (p->code[i] >> 6) & 0xFF;
            int b = (p->code[i] >> 23) & 0x1FF;
            int c = (p->code[i] >> 14) & 0x1FF;
            if (a == 1 && b == state_reg && c >= 256 &&
                i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_JMP) {
                disp_start = i;
                break;
            }
        }
    }
    if (disp_start < 0) { EDBG("[excflow] skip: disp_start not found (state_reg=%d)\n", state_reg); return; }

    /* collect state transition points: LOADK state_reg,K(sid) followed by JMP to disp_start */
    int *tpos = (int *)malloc(sizeof(int) * n);
    long long *tsid = (long long *)malloc(sizeof(long long) * n);
    int ntrans = 0;
    for (int i = disp_start + 1; i < n - 1; i++) {
        if ((p->code[i] & 0x3F) != LUAC_OP_LOADK) continue;
        int a = (p->code[i] >> 6) & 0xFF;
        int bx = (p->code[i] >> 14) & 0x3FFFF;
        if (a != state_reg || bx >= p->sizek) continue;
        if (!(p->k_tag[bx] == LUA_TNUMINT || p->k_tag[bx] == LUA_TNUMFLT)) continue;
        if ((p->code[i+1] & 0x3F) != LUAC_OP_JMP) continue;
        int jmp_sbx = (int)(p->code[i+1] >> 14) - 131071;
        if ((i+1) + 1 + jmp_sbx != disp_start) continue;
        long long sid = (p->k_tag[bx]==LUA_TNUMINT) ? p->k_int[bx] : (long long)p->k_num[bx];
        tpos[ntrans] = i;
        tsid[ntrans] = sid;
        ntrans++;
    }
    if (ntrans < 2) { EDBG("[excflow] skip: ntrans=%d (disp_start=%d)\n", ntrans, disp_start); free(tpos); free(tsid); return; }

    /* select up to max_replace random transitions */
    int max_replace = 8;
    /* Fisher-Yates partial shuffle */
    for (int i = ntrans - 1; i > 0; i--) {
        int j = obf_rand() % (i + 1);
        int tmp = tpos[i]; tpos[i] = tpos[j]; tpos[j] = tmp;
        long long tmp2 = tsid[i]; tsid[i] = tsid[j]; tsid[j] = tmp2;
    }
    /* sort selected by position descending so insertions don't shift later positions */
    for (int i = 0; i < max_replace; i++) {
        for (int j = i + 1; j < max_replace; j++) {
            if (tpos[j] > tpos[i]) {
                int tmp = tpos[i]; tpos[i] = tpos[j]; tpos[j] = tmp;
                long long tmp2 = tsid[i]; tsid[i] = tsid[j]; tsid[j] = tmp2;
            }
        }
    }

    /* registers */
    int func_reg = p->maxstacksize;
    int env_reg = func_reg + 1;
    int pcall_reg = env_reg + 1;
    int tmp_reg = pcall_reg + 3; /* temp for constant name */
    int err_reg = tmp_reg + 1;   /* stores error function */
    if (err_reg + 1 > 255) { free(tpos); free(tsid); return; }
    obf_ensure_stack(p, err_reg + 1);

    int kpcall = get_string_const_idx(p, "pcall");
    int kerror = get_string_const_idx(p, "error");

    EDBG("[exception_flow] state_reg=%d disp_start=%d ntrans=%d replace=%d kpcall=%d kerror=%d\n",
         state_reg, disp_start, ntrans, max_replace, kpcall, kerror);

    /* process from back to front so positions stay valid */
    int replaced_pos[64];
    int nreplaced = 0;
    for (int r = 0; r < max_replace; r++) {
        int pos = tpos[r];
        long long sid = tsid[r];
        int orig_jmp_a = (p->code[pos+1] >> 6) & 0xFF; /* preserve close level */
        EDBG("[excflow] replace r=%d pos=%d sid=%lld orig_jmp_a=%d\n", r, pos, sid, orig_jmp_a);
        replaced_pos[nreplaced++] = pos;

        /* create sub proto and append to parent */
        luac_Proto *sub = create_error_subproto(sid);
        p->p = realloc(p->p, sizeof(luac_Proto *) * (p->sizep + 1));
        p->p[p->sizep] = sub;
        int sub_idx = p->sizep;
        p->sizep++;

        /* replacement: 11 instructions (use LOADK for const names since RK may overflow) */
        unsigned int repl[11];
        repl[0] = LUAC_ABC(LUAC_OP_GETUPVAL, env_reg, 0, 0);  /* _ENV */
        repl[1] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, kpcall);    /* "pcall" */
        repl[2] = LUAC_ABC(LUAC_OP_GETTABLE, pcall_reg, env_reg, tmp_reg);  /* pcall = _ENV["pcall"] */
        repl[3] = LUAC_ABx(LUAC_OP_LOADK, tmp_reg, kerror);    /* "error" */
        repl[4] = LUAC_ABC(LUAC_OP_GETTABLE, err_reg, env_reg, tmp_reg);    /* error = _ENV["error"] */
        repl[5] = LUAC_ABx(LUAC_OP_CLOSURE, func_reg, sub_idx);
        repl[6] = LUAC_ABC(LUAC_OP_MOVE, pcall_reg + 1, func_reg, 0);  /* f */
        repl[7] = LUAC_ABC(LUAC_OP_MOVE, pcall_reg + 2, err_reg, 0);   /* error */
        repl[8] = LUAC_ABC(LUAC_OP_CALL, pcall_reg, 3, 3);  /* pcall(f, error) -> ok, err */
        repl[9] = LUAC_ABC(LUAC_OP_MOVE, state_reg, pcall_reg + 1, 0);  /* state = err */
        /* JMP to dispatcher — sbx will be fixed after insertion */
        repl[10] = 0;

        /* mark JMPs targeting [pos, pos+2) with sentinel sbx before insertion */
        int sentinel = -131071; /* impossible target (negative) */
        for (int ji = 0; ji < p->sizecode; ji++) {
            int jop = p->code[ji] & 0x3F;
            if (jop != LUAC_OP_JMP && jop != LUAC_OP_FORLOOP &&
                jop != LUAC_OP_FORPREP && jop != LUAC_OP_TFORLOOP) continue;
            int jsbx = (int)(p->code[ji] >> 14) - 131071;
            int jtarget = ji + 1 + jsbx;
            if (jtarget >= pos && jtarget < pos + 2) {
                EDBG("[excflow] mark JMP at [%d] target=%d for fix to %d\n", ji, jtarget, pos);
                p->code[ji] = (p->code[ji] & 0x3FFF) | ((unsigned int)(sentinel + 131071) << 14);
            }
        }

        /* replace 2 instructions with 11: insert 9 after pos */
        int insert_count = 9;
        p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + insert_count));
        memmove(&p->code[pos + 2 + insert_count], &p->code[pos + 2],
                sizeof(unsigned int) * (p->sizecode - pos - 2));
        p->sizecode += insert_count;

        /* write replacement */
        for (int k = 0; k < 11; k++) p->code[pos + k] = repl[k];

        /* fix JMP targets for instructions shifted by insertion */
        obf_adjust_jumps_insert(p->code, p->sizecode, pos + 3, insert_count);

        /* fix marked JMPs: set target to pos */
        for (int ji = 0; ji < p->sizecode; ji++) {
            int jop = p->code[ji] & 0x3F;
            if (jop != LUAC_OP_JMP && jop != LUAC_OP_FORLOOP &&
                jop != LUAC_OP_FORPREP && jop != LUAC_OP_TFORLOOP) continue;
            int jsbx = (int)(p->code[ji] >> 14) - 131071;
            if (jsbx == sentinel) {
                int newsbx = pos - ji - 1;
                p->code[ji] = (p->code[ji] & 0x3FFF) | ((unsigned int)(newsbx + 131071) << 14);
            }
        }

        /* now set the JMP at pos+10 to jump to disp_start */
        int sbx = disp_start - (pos + 10) - 1;
        p->code[pos + 10] = LUAC_AsBx(LUAC_OP_JMP, orig_jmp_a, sbx);
    }

    if (p->lineinfo) { free(p->lineinfo); p->lineinfo = NULL; p->sizelineinfo = 0; }
    free(tpos); free(tsid);
}

int exception_flow_process(lua_State *L) {
    luac_Proto *p = obf_check_proto(L);
    luac_sync_proto(L, 1);
    obf_invalidate_all_caches(L, p);

    /* only process main proto — sub-protos are not flattened, no state machine */
    exception_flow_function(p);

    lua_pushinteger(L, 1);
    return 1;
}
