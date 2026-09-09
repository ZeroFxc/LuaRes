/*
** vm_dispatch.c - VM dispatch obfuscation (vm_dispatch_shuffle)
**
** Randomizes the generated VM's opcode numbering and the shape of its
** main dispatch loop, so each round produces a different, less readable
** instruction set. Three dispatch shapes:
**   mode 0: ordered if/elseif chain (unchanged behavior)
**   mode 1: if/elseif chain with shuffled branch order
**   mode 2: table lookup   _dispatch[op](a,b,c,bx,sbx)
**   mode 3: arithmetic slot ((op*A+B)%nops)+1 -> table lookup
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

void vm_dispatch_set(unsigned int seed, int mode) {
    g_ds_seed = seed;
    g_ds_mode = (mode >= 0 && mode <= 3) ? mode : 0;
}
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

/* ---------- main dispatch loop generator ---------- */
char *vm_gen_dispatch(const VmOp *ops, int nops, const int *remap, int mode,
                      const char *R, const char *K, const char *UV, const char *PC,
                      int luajit_compat, unsigned int seed, size_t *len) {
    VmBuf b; vmbuf_init(&b);

    /* body helper macro: pick compat or normal body */
#define BODY_OF(i) ((luajit_compat && ops[(i)].body_compat) ? ops[(i)].body_compat : ops[(i)].body)

    vmbuf_printf(&b, "  local function RK(x) if x < 256 then return %s[x] end return %s[x - 255] end\n", R, K);

    if (mode == 2 || mode == 3) {
        /* ---------- table dispatch ---------- */
        vmbuf_puts(&b, "  local _dispatch = {\n");
        if (mode == 3) {
            /* arithmetic slot: slot = (op*A + B) % nops + 1, gcd(A, nops) == 1
               nops = 54 = 2*3^3, so A must be odd and not a multiple of 3. */
            vm_srand(seed);
            int A;
            do { A = (int)(vm_rand() % 10000) | 1; } while (A % 3 == 0);
            int B = (int)(vm_rand() % nops);
            for (int s = 1; s <= nops; s++) {
                int found = -1;
                for (int i = 0; i < nops; i++) {
                    if (!BODY_OF(i)) continue;
                    int opcode = remap ? remap[ops[i].op] : ops[i].op;
                    if (((opcode * A + B) % nops) + 1 == s) { found = i; break; }
                }
                if (found >= 0) {
                    vmbuf_printf(&b, "    [%d] = function(a,b,c,bx,sbx) ", s);
                    vm_emit_body(&b, BODY_OF(found), R, K, UV, PC, "a", "b", "c", "bx", "sbx");
                    vmbuf_puts(&b, " end,\n");
                } else {
                    vmbuf_printf(&b, "    [%d] = nil,\n", s);
                }
            }
            vmbuf_puts(&b, "  }\n");
            vmbuf_printf(&b, "  while %s <= #code do\n", PC);
            vmbuf_printf(&b, "    local ins = code[%s]\n", PC);
            vmbuf_printf(&b, "    local op = ins[1]\n");
            vmbuf_printf(&b, "    local a = ins[2] or 0\n");
            vmbuf_printf(&b, "    local b = ins[3] or 0\n");
            vmbuf_printf(&b, "    local c = ins[4] or 0\n");
            vmbuf_printf(&b, "    local bx = ins[5] or 0\n");
            vmbuf_printf(&b, "    local sbx = bx - 131071\n");
            vmbuf_printf(&b, "    local _h = _dispatch[((op * %d + %d) %% %d) + 1]\n", A, B, nops);
            vmbuf_puts(&b, "    if _h then _h(a,b,c,bx,sbx) end\n");
            vmbuf_puts(&b, "  end\n");
        } else {
            /* mode 2: direct table keyed by opcode */
            for (int i = 0; i < nops; i++) {
                if (!BODY_OF(i)) continue;
                int opcode = remap ? remap[ops[i].op] : ops[i].op;
                vmbuf_printf(&b, "    [%d] = function(a,b,c,bx,sbx) ", opcode);
                vm_emit_body(&b, BODY_OF(i), R, K, UV, PC, "a", "b", "c", "bx", "sbx");
                vmbuf_puts(&b, " end,\n");
            }
            vmbuf_puts(&b, "  }\n");
            vmbuf_printf(&b, "  while %s <= #code do\n", PC);
            vmbuf_printf(&b, "    local ins = code[%s]\n", PC);
            vmbuf_printf(&b, "    local op = ins[1]\n");
            vmbuf_printf(&b, "    local a = ins[2] or 0\n");
            vmbuf_printf(&b, "    local b = ins[3] or 0\n");
            vmbuf_printf(&b, "    local c = ins[4] or 0\n");
            vmbuf_printf(&b, "    local bx = ins[5] or 0\n");
            vmbuf_printf(&b, "    local sbx = bx - 131071\n");
            vmbuf_printf(&b, "    local _h = _dispatch[op]\n");
            vmbuf_puts(&b, "    if _h then _h(a,b,c,bx,sbx) end\n");
            vmbuf_puts(&b, "  end\n");
        }
        vmbuf_printf(&b, "  closeuv(0)\n");
        return vmbuf_detach(&b, len);
    }

    /* ---------- if/elseif chain (mode 0 ordered, mode 1 shuffled) ---------- */
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
        vm_emit_body(&b, BODY_OF(order[i]), R, K, UV, PC, "a", "b", "c", "bx", "sbx");
        vmbuf_putc(&b, '\n');
    }
    vmbuf_printf(&b, "    end\n");
    vmbuf_printf(&b, "    %s = %s + 1\n", PC, PC);
    vmbuf_puts(&b, "  end\n");
    vmbuf_printf(&b, "  closeuv(0)\n");

    return vmbuf_detach(&b, len);
}

/* ---------- Lua entry: vm_dispatch_shuffle_c({seed=, mode=}) ---------- */
int vm_dispatch_shuffle_process(lua_State *L) {
    unsigned int seed = 0;
    int mode = 0;
    if (lua_gettop(L) >= 1 && lua_istable(L, 1)) {
        lua_getfield(L, 1, "seed");
        if (lua_isnumber(L, -1)) seed = (unsigned int)lua_tointeger(L, -1);
        lua_pop(L, 1);
        lua_getfield(L, 1, "mode");
        if (lua_isnumber(L, -1)) mode = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
    }
    if (mode < 0 || mode > 3) mode = 0;
    if (seed == 0) seed = (unsigned int)time(NULL);  /* each round differs */
    vm_dispatch_set(seed, mode);
    return 0;
}
