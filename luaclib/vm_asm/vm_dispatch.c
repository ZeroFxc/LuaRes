/*
** vm_dispatch.c - VM dispatch obfuscation (vm_dispatch_shuffle)
**
** Randomizes the generated VM's opcode numbering and the shape of its
** main dispatch loop, so each round produces a different, less readable
** instruction set. Four dispatch shapes:
**   mode 0: ordered if/elseif chain (unchanged behavior)
**   mode 1: if/elseif chain with shuffled branch order
**   mode 2: table lookup   _dispatch[op](a,b,c,bx,sbx,...)
**   mode 3: arithmetic slot ((op*A+B)%nops)+1 -> table lookup
**   mode 4: tail-call threaded (decentralized) — no while loop;
**           each opcode handler is a closure inside execute() and ends
**           with `return _dispatch[code[pc][1]]()`, forming a handler
**           chain. RETURN/TAILCALL bodies already `return` and exit the chain.
**
** Modes 2/3 emit a module-level dispatch table of handler closures bound
** only to module-level runtime helpers (docall & friends); the VM state
** (R/K/UV/pc/code/top/proto/vararg/execute) is passed to each handler as
** parameters from execute()'s own locals. This keeps coroutine suspension
** safe (state lives in the coroutine stack, not in shared cells) while
** avoiding per-CALL closure rebuilding. RETURN/TAILCALL get sentinel
** entries and are inlined in the main loop, so their "return" semantics
** exit execute() itself.
**
** Global state set by vm_dispatch_shuffle_c (Lua) / vm_dispatch_set (C),
** consumed by vm_embed_generate. vm_embed runs last, so the remap and
** dispatch shape only affect the final self-contained VM output.
*/
#include "vm_asm.h"
#include "obf_util.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* ---------- global dispatch configuration ---------- */
static unsigned int g_ds_seed = 0;
static int g_ds_mode = 0;
static int g_ds_has_explicit = 0;

void vm_dispatch_set(unsigned int seed, int mode) {
    g_ds_seed = seed;
    g_ds_mode = (mode >= 0 && mode <= 5) ? mode : 0;
}
void vm_dispatch_set_explicit(unsigned int seed, int mode) {
    g_ds_seed = seed;
    g_ds_mode = (mode >= 0 && mode <= 5) ? mode : 0;
    g_ds_has_explicit = 1;
}
void vm_dispatch_reset(void) {
    g_ds_seed = 0;
    g_ds_mode = 0;
    g_ds_has_explicit = 0;
}
int vm_dispatch_has_explicit(void) { return g_ds_has_explicit; }
unsigned int vm_dispatch_get_seed(void) { return g_ds_seed; }
int vm_dispatch_get_mode(void) { return g_ds_mode; }

/* ---------- opcode remap table (Fisher-Yates, deterministic by seed) ---------- */
int *vm_dispatch_make_remap(unsigned int seed, int nops) {
    int *map = malloc(nops * sizeof(int));
    int *inv = malloc(nops * sizeof(int));
    for (int i = 0; i < nops; i++) inv[i] = i;
    vm_srand(seed);
    for (int i = nops - 1; i > 0; i--) {
        int j = vm_rand() % (i + 1);
        int t = inv[i]; inv[i] = inv[j]; inv[j] = t;
    }
    for (int i = 0; i < nops; i++) map[inv[i]] = i;
    free(inv);
    return map;
}

/* which ops carry RETURN / TAILCALL semantics (need sentinel inlining) */
#define DS_OP_TAILCALL 37
#define DS_OP_RETURN   38
#define DS_OP_RETURN2  53   /* andlua TRYRETURN: same return semantics */


/* does the template end with {NEXT} or a {JMP:...} token? (then it already
   returns pc and no trailing `return pc, top` may be appended) */
static int body_ends_ret(const char *body) {
    size_t n = strlen(body);
    while (n > 0 && (body[n-1] == ' ' || body[n-1] == '\t' ||
                     body[n-1] == '\n' || body[n-1] == '\r')) n--;
    if (n == 0) return 0;
    if (n >= 6 && strncmp(body + n - 6, "{NEXT}", 6) == 0) return 1;
    if (body[n-1] != '}') return 0;
    {
        const char *p = body + n - 1;  /* trailing '}' */
        int depth = 1;                 /* consumed it */
        while (p > body) {
            p--;
            if (*p == '}') depth++;
            else if (*p == '{') {
                depth--;
                if (depth == 0) return strncmp(p, "{JMP:", 5) == 0;
            }
        }
    }
    return 0;
}

/* ---------- module-level prelude for table/arithmetic dispatch ----------
   Emits RK (3-arg), sentinels, and the _dispatch table of handler closures.
   Handlers receive the full VM state as parameters. */
char *vm_gen_dispatch_prelude(const VmOp *ops, int nops, const int *remap, int mode,
                              int luajit_compat, unsigned int seed, size_t *len) {
    VmBuf b; vmbuf_init(&b);

    vmbuf_puts(&b,
        "  local function RK(x, R, K) if x < 256 then return R[x] end return K[x - 255] end\n"
        "  local _RET = {}\n"
        "  local _TAIL = {}\n"
        "  local _dispatch = {\n");

    if (mode == 3) {
        vm_srand(seed);
        int A;
        do { A = (int)(vm_rand() % 10000) | 1; } while (A % 3 == 0);
        int B = (int)(vm_rand() % nops);
        for (int s = 1; s <= nops; s++) {
            int found = -1;
            for (int i = 0; i < nops; i++) {
                const char *body = (luajit_compat && ops[i].body_compat) ? ops[i].body_compat : ops[i].body;
                if (!body) continue;
                int opcode = remap ? remap[ops[i].op] : ops[i].op;
                if (((opcode * A + B) % nops) + 1 == s) { found = i; break; }
            }
            if (found >= 0) {
                if (ops[found].op == DS_OP_RETURN || ops[found].op == DS_OP_RETURN2 ||
                    ops[found].op == DS_OP_TAILCALL) {
                    vmbuf_printf(&b, "    [%d] = %s,\n", s,
                                 (ops[found].op == DS_OP_TAILCALL) ? "_TAIL" : "_RET");
                } else {
                    const char *fbody = (luajit_compat && ops[found].body_compat) ? ops[found].body_compat : ops[found].body;
                    vmbuf_printf(&b, "    [%d] = function(a,b,c,bx,sbx, R,K,UV,pc,code,top,proto,vararg,execute) ", s);
                    vm_emit_body(&b, fbody, "R", "K", "UV", "pc", "code",
                                 "top", "proto",
                                 "a", "b", "c", "bx", "sbx", 1);
                    if (!body_ends_ret(fbody)) vmbuf_puts(&b, " return pc, top");
                    vmbuf_puts(&b, " end,\n");
                }
            } else {
                vmbuf_printf(&b, "    [%d] = nil,\n", s);
            }
        }
    } else {
        for (int i = 0; i < nops; i++) {
            const char *body = (luajit_compat && ops[i].body_compat) ? ops[i].body_compat : ops[i].body;
            if (!body) continue;
            int opcode = remap ? remap[ops[i].op] : ops[i].op;
            if (ops[i].op == DS_OP_RETURN || ops[i].op == DS_OP_RETURN2 ||
                ops[i].op == DS_OP_TAILCALL) {
                vmbuf_printf(&b, "    [%d] = %s,\n", opcode,
                             (ops[i].op == DS_OP_TAILCALL) ? "_TAIL" : "_RET");
            } else {
                vmbuf_printf(&b, "    [%d] = function(a,b,c,bx,sbx, R,K,UV,pc,code,top,proto,vararg,execute) ", opcode);
                vm_emit_body(&b, body, "R", "K", "UV", "pc", "code",
                             "top", "proto",
                             "a", "b", "c", "bx", "sbx", 1);
                if (!body_ends_ret(body)) vmbuf_puts(&b, " return pc, top");
                vmbuf_puts(&b, " end,\n");
            }
        }
    }

    vmbuf_puts(&b, "  }\n");
    return vmbuf_detach(&b, len);
}

/* ---------- main dispatch loop generator ---------- */
char *vm_gen_dispatch(const VmOp *ops, int nops, const int *remap, int mode,
                      const char *R, const char *K, const char *UV, const char *PC,
                      int luajit_compat, unsigned int seed, size_t *len) {
    VmBuf b; vmbuf_init(&b);

#define BODY_OF(i) ((luajit_compat && ops[(i)].body_compat) ? ops[(i)].body_compat : ops[(i)].body)

    if (mode == 2 || mode == 3) {
        /* ---------- table dispatch (state passed by parameter) ---------- */
        vmbuf_printf(&b,
            "  while %s <= #code do\n"
            "    local ins = code[%s]\n"
            "    local op = ins[1]\n"
            "    local a = ins[2] or 0\n"
            "    local b = ins[3] or 0\n"
            "    local c = ins[4] or 0\n"
            "    local bx = ins[5] or 0\n"
            "    local sbx = bx - 131071\n", PC, PC);
        if (mode == 3) {
            vm_srand(seed);
            int A;
            do { A = (int)(vm_rand() % 10000) | 1; } while (A % 3 == 0);
            int B = (int)(vm_rand() % nops);
            vmbuf_printf(&b, "    local _h = _dispatch[((op * %d + %d) %% %d) + 1]\n", A, B, nops);
        } else {
            vmbuf_puts(&b, "    local _h = _dispatch[op]\n");
        }
        vmbuf_printf(&b,
            "    if _h == _RET then\n"
            "      local _t = {doreturn(a,b, top, %s)}\n"
            "      return _unpack(_t, 1, _t.n)\n"
            "    elseif _h == _TAIL then\n"
            "      local _t = {dotailcall(a,b, %s, top, execute)}\n"
            "      return _unpack(_t, 1, _t.n)\n"
            "    elseif _h then\n"
            "      local _p, _t = _h(a,b,c,bx,sbx, %s, %s, %s, %s, code, top, proto, vararg, execute)\n"
            "      if _p then pc = _p end\n"
            "      if _t then top = _t end\n"
            "    end\n"
            "    %s = %s + 1\n"
            "  end\n"
            "  closeuv(0)\n",
            R,
            R,
            R, K, UV, PC,
            PC, PC);
        return vmbuf_detach(&b, len);
    }

    if (mode == 4) {
        /* ---------- tail-call threaded (decentralized, no while loop) ---------- */
        /* random dispatch-table identifier (seed-derived, avoids static _dispatch name) */
        const char *_idc = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789";
        char dname[32];
        unsigned int _r4 = seed * 2654435761u + 0x9e3779b9u;
        int _dlen4 = 6 + (_r4 % 7);  /* 6-12 chars */
        dname[0] = '_';
        for (int _i4 = 1; _i4 < _dlen4; _i4++) {
            _r4 = _r4 * 1103515245u + 12345u;
            dname[_i4] = _idc[_r4 % 63];
        }
        dname[_dlen4] = '\0';

        vmbuf_printf(&b, "  local function RK(x, R, K) if x < 256 then return R[x] end return K[x - 255] end\n");
        vmbuf_printf(&b, "  local %s = {}\n", dname);

        int order4[64];
        int nused4 = 0;
        for (int i = 0; i < nops; i++) {
            if (BODY_OF(i)) order4[nused4++] = i;
        }

        for (int i = 0; i < nused4; i++) {
            const VmOp *op = &ops[order4[i]];
            int opcode = remap ? remap[op->op] : op->op;
            const char *body = BODY_OF(order4[i]);
            int has_ret = (strstr(body, "return") != NULL);

            vmbuf_printf(&b, "  %s[%d] = function()\n", dname, opcode);
            vmbuf_puts(&b, "    local ins = code[pc]\n");
            vmbuf_puts(&b, "    local a = ins[2] or 0; local b = ins[3] or 0; local c = ins[4] or 0\n");
            vmbuf_puts(&b, "    local bx = ins[5] or 0; local sbx = bx - 131071\n");
            vmbuf_puts(&b, "    ");
            vm_emit_body(&b, body, R, K, UV, PC, "code", "top", "proto",
                         "a", "b", "c", "bx", "sbx", 0);
            vmbuf_putc(&b, '\n');
            if (!has_ret) {
                vmbuf_printf(&b, "    %s = %s + 1\n", PC, PC);
                vmbuf_printf(&b, "    if %s <= #code then return %s[code[%s][1]]() end\n", PC, dname, PC);
                vmbuf_puts(&b, "    return\n");
            }
            vmbuf_puts(&b, "  end\n");
        }

        vmbuf_printf(&b, "  if %s <= #code then return %s[code[%s][1]]() end\n", PC, dname, PC);
        vmbuf_puts(&b, "  closeuv(0)\n");

        return vmbuf_detach(&b, len);
    }

    if (mode == 5) {
        /* ---------- VMP-style decentralized: rolling-key handler chain ---------- */
        /* No while loop, no if/elseif dispatch, no central dispatch-table lookup.
         * Each handler ends by decrypting the next handler opcode from nxt_table
         * using a rolling key, then tail-calls it. Jump targets are encrypted,
         * static analysis cannot recover the control-flow graph. */
        const char *_idc5 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789";
        char hname[32], nname[32];
        unsigned int _r5 = seed * 2654435761u + 0x9e3779b9u;
        int _hl = 6 + (_r5 % 7);
        hname[0] = '_';
        for (int _i = 1; _i < _hl; _i++) { _r5 = _r5 * 1103515245u + 12345u; hname[_i] = _idc5[_r5 % 63]; }
        hname[_hl] = '\0';
        int _nl = 6 + (_r5 % 7);
        nname[0] = '_';
        for (int _i = 1; _i < _nl; _i++) { _r5 = _r5 * 1103515245u + 12345u; nname[_i] = _idc5[_r5 % 63]; }
        nname[_nl] = '\0';

        vmbuf_printf(&b, "  local function RK(x, R, K) if x < 256 then return R[x] end return K[x - 255] end\n");
        /* encrypted next-handler table */
        vmbuf_printf(&b, "  local %s = {}\n", nname);
        vmbuf_puts(&b, "  do\n");
        vmbuf_puts(&b, "    for _i = 1, #code do\n");
        vmbuf_puts(&b, "      local _rk = (_i * 0x9e3779b1 + 0x5bd1e995) % 0x100000000\n");
        vmbuf_printf(&b, "      %s[_i] = (_i < #code) and (code[_i+1][1] ~ _rk) or 0\n", nname);
        vmbuf_puts(&b, "    end\n");
        vmbuf_puts(&b, "  end\n");
        /* handler pool */
        vmbuf_printf(&b, "  local %s = {}\n", hname);

        int order5[64];
        int nused5 = 0;
        for (int i = 0; i < nops; i++) {
            if (BODY_OF(i)) order5[nused5++] = i;
        }

        for (int i = 0; i < nused5; i++) {
            const VmOp *op = &ops[order5[i]];
            int opcode = remap ? remap[op->op] : op->op;
            const char *body = BODY_OF(order5[i]);
            int has_ret = (strstr(body, "return") != NULL);

            vmbuf_printf(&b, "  %s[%d] = function()\n", hname, opcode);
            vmbuf_puts(&b, "    local ins = code[pc]\n");
            vmbuf_puts(&b, "    local a = ins[2] or 0; local b = ins[3] or 0; local c = ins[4] or 0\n");
            vmbuf_puts(&b, "    local bx = ins[5] or 0; local sbx = bx - 131071\n");
            vmbuf_puts(&b, "    ");
            vm_emit_body(&b, body, R, K, UV, PC, "code", "top", "proto",
                         "a", "b", "c", "bx", "sbx", 0);
            vmbuf_putc(&b, '\n');
            if (!has_ret) {
                /* rolling key from pc (body may have jumped), decrypt next handler */
                vmbuf_puts(&b, "    local rk = (pc * 0x9e3779b1 + 0x5bd1e995) % 0x100000000\n");
                vmbuf_printf(&b, "    local nxt = %s[pc] ~ rk\n", nname);
                vmbuf_printf(&b, "    %s = %s + 1\n", PC, PC);
                vmbuf_printf(&b, "    if %s <= #code then return %s[nxt]() end\n", PC, hname);
                vmbuf_puts(&b, "    return\n");
            }
            vmbuf_puts(&b, "  end\n");
        }

        /* entry: first handler is direct (only entry is visible, rest is rolling-key protected) */
        vmbuf_printf(&b, "  if %s <= #code then return %s[code[%s][1]]() end\n", PC, hname, PC);
        vmbuf_puts(&b, "  closeuv(0)\n");

        return vmbuf_detach(&b, len);
    }

    /* ---------- if/elseif chain (mode 0 ordered, mode 1 shuffled) ---------- */
    vmbuf_printf(&b, "  local function RK(x, R, K) if x < 256 then return R[x] end return K[x - 255] end\n");

    int order[64];
    int nused = 0;
    for (int i = 0; i < nops; i++) {
        if (BODY_OF(i)) order[nused++] = i;
    }
    if (mode == 1) {
        vm_srand(seed);
        for (int i = nused - 1; i > 0; i--) {
            int j = vm_rand() % (i + 1);
            int t = order[i]; order[i] = order[j]; order[j] = t;
        }
    }

    vmbuf_printf(&b, "  while %s <= #code do\n", PC);
    vmbuf_printf(&b, "    local ins = code[%s]\n", PC);
    vmbuf_printf(&b, "    local op = ins[1]\n");
    vmbuf_printf(&b, "    local a = ins[2] or 0\n");
    vmbuf_printf(&b, "    local b = ins[3] or 0\n");
    vmbuf_printf(&b, "    local c = ins[4] or 0\n");
    vmbuf_printf(&b, "    local bx = ins[5] or 0\n");
    vmbuf_printf(&b, "    local sbx = bx - 131071\n");
    vmbuf_printf(&b, "    if false then\n");
    for (int i = 0; i < nused; i++) {
        const VmOp *op = &ops[order[i]];
        int opcode = remap ? remap[op->op] : op->op;
        vmbuf_printf(&b, "    elseif op == %d then\n", opcode);
        vmbuf_puts(&b, "      ");
        vm_emit_body(&b, BODY_OF(order[i]), R, K, UV, PC, "code", "top", "proto",
                     "a", "b", "c", "bx", "sbx", 0);
        vmbuf_putc(&b, '\n');
    }
    vmbuf_printf(&b, "    end\n");
    vmbuf_printf(&b, "    %s = %s + 1\n", PC, PC);
    vmbuf_puts(&b, "  end\n");
    vmbuf_printf(&b, "  closeuv(0)\n");

    return vmbuf_detach(&b, len);
#undef BODY_OF
}

/* ---------- Lua entry: vm_dispatch_shuffle_c({seed=, mode=}) ---------- */
int vm_dispatch_shuffle_process(lua_State *L) {
    unsigned int seed = 0;
    int mode = 0;
    if (lua_gettop(L) >= 2 && lua_istable(L, 2)) {
        lua_getfield(L, 2, "seed");
        if (lua_isnumber(L, -1)) seed = (unsigned int)lua_tointeger(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 2, "mode");
        if (lua_isnumber(L, -1)) mode = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    if (vm_dispatch_has_explicit()) {
        seed = vm_dispatch_get_seed();
        mode = vm_dispatch_get_mode();
    } else {
        if (mode < 0 || mode > 5) mode = 0;
        if (seed == 0) seed = (unsigned int)time(NULL);  /* each round differs */
        vm_dispatch_set(seed, mode);
    }
    return 0;
}
