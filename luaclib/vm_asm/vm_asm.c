/*
** vm_asm.c - Main assembler: composes all components into a complete VM.
**
** Composition order:
**   1. Header (module declaration)
**   2. execute() function wrapper with frame setup
**   3. Runtime helpers (upvalue, closure, call/return, vararg, coroutine)
**   4. Main dispatch loop (from opcode table)
**   5. Loader (load_chunk)
**   6. Stdlib bridge
**   7. Public API (VM.load/run/exec/pack)
*/
#include "vm_asm.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ---- header ---- */
char *vm_gen_header(size_t *len) {
    VmBuf b; vmbuf_init(&b);
    vmbuf_puts(&b,
        "local execute\n"
        "local closure_map = setmetatable({}, {__mode = 'k'})\n\n");
    return vmbuf_detach(&b, len);
}

/* ---- opcode constants ---- */
char *vm_gen_opcodes(const int *remap, int luajit_compat, size_t *len) {
    VmBuf b; vmbuf_init(&b);
    int nops;
    const VmOp *ops = vm_op_table(&nops);
    for (int i = 0; i < nops; i++) {
        const char *body = (luajit_compat && ops[i].body_compat) ? ops[i].body_compat : ops[i].body;
        int opcode = remap ? remap[ops[i].op] : ops[i].op;
        if (body)
            vmbuf_printf(&b, "local OP_%s = %d\n", ops[i].name, opcode);
        else
            vmbuf_printf(&b, "-- local OP_%s = %d  (no handler)\n", ops[i].name, opcode);
    }
    vmbuf_putc(&b, '\n');
    return vmbuf_detach(&b, len);
}

/* ---- main entry ---- */
int vm_assemble(VmAsmOpts *opts) {
    if (opts->seed) vm_srand(opts->seed);

    int nops;
    const VmOp *ops = vm_op_table(&nops);

    /* variable names */
    char vR[16], vK[16], vUV[16], vPC[16], vTOP[16], vPROTO[16];
    if (opts->obfuscate_names) {
        vm_gen_id(vR, 6); vm_gen_id(vK, 6); vm_gen_id(vUV, 6);
        vm_gen_id(vPC, 6); vm_gen_id(vTOP, 6); vm_gen_id(vPROTO, 6);
    } else {
        strcpy(vR, "R"); strcpy(vK, "K"); strcpy(vUV, "UV");
        strcpy(vPC, "pc"); strcpy(vTOP, "top"); strcpy(vPROTO, "proto");
    }

    /* remap */
    int *remap = NULL;
    if (opts->remap || opts->dispatch_mode)
        remap = vm_dispatch_make_remap(opts->seed ? opts->seed : 1, nops);

    VmBuf out; vmbuf_init(&out);

    /* 1. header */
    size_t l; char *p;
    p = vm_gen_header(&l); vmbuf_puts(&out, p); free(p);

    /* 2. opcode constants */
    p = vm_gen_opcodes(remap, opts->luajit_compat, &l); vmbuf_puts(&out, p); free(p);

    /* 2b. dispatch mode: module-level cells + runtime copy + dispatch prelude */
    if (opts->dispatch_mode) {
        p = vm_gen_runtime(vR, vK, vUV, vPC, vTOP, vPROTO,
                           opts->include_coroutine, opts->luajit_compat, &l);
        vmbuf_puts(&out, p); free(p);
        p = vm_gen_dispatch_prelude(ops, nops, remap, opts->dispatch_mode,
                                    opts->luajit_compat, opts->seed ? opts->seed : 1, &l);
        vmbuf_puts(&out, p); free(p);
    }

    /* 3. execute function */
    vmbuf_printf(&out,
        "local execute\n"
        "local _G = _G or (getfenv and getfenv(0)) or {}"
        "execute = function(closure, ...)\n"
        "  local _cl = closure_map[closure]\n"
        "  if not _cl and type(closure) == 'table' and closure.proto then _cl = closure end\n"
        "  if not _cl then _cl = closure end\n"
        "  local %s = _cl.proto\n"
        "  local %s = {}\n"
        "  local %s = %s.k\n"
        "  local code = %s.code\n"
        "  local %s = _cl.upvals\n"
        "  if not %s[0] or not %s[0].val then %s[0] = {val = _G} end\n"
        "  local %s = 1\n"
        "  local %s = %s.maxstacksize\n"
        "  local vararg = {...}\n"
        "  local _nva = select('#', ...)\n"
        "  for i = 1, %s.num_params do %s[i-1] = vararg[i] end\n"
        "  local _va = {}\n"
        "  local _vac = 0\n"
        "  for i = %s.num_params + 1, _nva do _vac = _vac + 1; _va[_vac] = vararg[i] end\n"
        "  _va.n = _vac\n"
        "  vararg = _va\n"
        "  top = proto.num_params + (_va.n or 0)\n",
        vPROTO, vR, vK, vPROTO, vPROTO, vUV, vUV, vUV, vUV, vPC, vTOP, vPROTO, vPROTO, vR, vPROTO);


    /* 4. runtime helpers */
    p = vm_gen_runtime(vR, vK, vUV, vPC, vTOP, vPROTO,
                       opts->include_coroutine, opts->luajit_compat, &l);
    vmbuf_puts(&out, p); free(p);

    /* 5. main loop */
    p = vm_gen_dispatch(ops, nops, remap, opts->dispatch_mode, vR, vK, vUV, vPC,
                        opts->luajit_compat, opts->seed ? opts->seed : 1, &l);
    vmbuf_puts(&out, p); free(p);

    /* 6. end execute */
    vmbuf_puts(&out, "end\n\n");

    /* 7. loader */
    p = vm_gen_loader(&l); vmbuf_puts(&out, p); free(p);

    /* 8. stdlib */
    p = vm_gen_stdlib(opts->include_debug, &l); vmbuf_puts(&out, p); free(p);

    /* 9. API */
    p = vm_gen_api(&l); vmbuf_puts(&out, p); free(p);

    if (remap) free(remap);

    opts->out = vmbuf_detach(&out, &opts->out_len);
    return 0;
}

/*
** Runtime-only assembly: executor + minimal proto builder, no load/pack/API.
** Used by vm_embed to produce self-contained "production" files.
*/
int vm_assemble_runtime(VmAsmOpts *opts) {
    if (opts->seed) vm_srand(opts->seed);

    int nops;
    const VmOp *ops = vm_op_table(&nops);

    char vR[16], vK[16], vUV[16], vPC[16], vTOP[16], vPROTO[16];
    if (opts->obfuscate_names) {
        vm_gen_id(vR, 6); vm_gen_id(vK, 6); vm_gen_id(vUV, 6);
        vm_gen_id(vPC, 6); vm_gen_id(vTOP, 6); vm_gen_id(vPROTO, 6);
    } else {
        strcpy(vR, "R"); strcpy(vK, "K"); strcpy(vUV, "UV");
        strcpy(vPC, "pc"); strcpy(vTOP, "top"); strcpy(vPROTO, "proto");
    }

    int *remap = NULL;
    if (opts->remap || opts->dispatch_mode)
        remap = vm_dispatch_make_remap(opts->seed ? opts->seed : 1, nops);

    VmBuf out; vmbuf_init(&out);

    /* 1. header */
    size_t l; char *p;
    p = vm_gen_header(&l); vmbuf_puts(&out, p); free(p);

    /* 2. opcode constants */
    p = vm_gen_opcodes(remap, opts->luajit_compat, &l); vmbuf_puts(&out, p); free(p);

    /* 2b. dispatch mode: module-level cells + runtime copy + dispatch prelude */
    if (opts->dispatch_mode) {
        p = vm_gen_runtime(vR, vK, vUV, vPC, vTOP, vPROTO,
                           opts->include_coroutine, opts->luajit_compat, &l);
        vmbuf_puts(&out, p); free(p);
        p = vm_gen_dispatch_prelude(ops, nops, remap, opts->dispatch_mode,
                                    opts->luajit_compat, opts->seed ? opts->seed : 1, &l);
        vmbuf_puts(&out, p); free(p);
    }

    /* 3. execute function */
    vmbuf_printf(&out,
        "local execute\n"
        "local _G = _G or (getfenv and getfenv(0)) or {}"
        "execute = function(closure, ...)\n"
        "  local _cl = closure_map[closure]\n"
        "  if not _cl and type(closure) == 'table' and closure.proto then _cl = closure end\n"
        "  if not _cl then _cl = closure end\n"
        "  local %s = _cl.proto\n"
        "  local %s = {}\n"
        "  local %s = %s.k\n"
        "  local code = %s.code\n"
        "  local %s = _cl.upvals\n"
        "  if not %s[0] or not %s[0].val then %s[0] = {val = _G} end\n"
        "  local %s = 1\n"
        "  local %s = %s.maxstacksize\n"
        "  local vararg = {...}\n"
        "  local _nva = select('#', ...)\n"
        "  for i = 1, %s.num_params do %s[i-1] = vararg[i] end\n"
        "  local _va = {}\n"
        "  local _vac = 0\n"
        "  for i = %s.num_params + 1, _nva do _vac = _vac + 1; _va[_vac] = vararg[i] end\n"
        "  _va.n = _vac\n"
        "  vararg = _va\n"
        "  top = proto.num_params + (_va.n or 0)\n",
        vPROTO, vR, vK, vPROTO, vPROTO, vUV, vUV, vUV, vUV, vPC, vTOP, vPROTO, vPROTO, vR, vPROTO);


    /* 4. runtime helpers */
    p = vm_gen_runtime(vR, vK, vUV, vPC, vTOP, vPROTO,
                       opts->include_coroutine, opts->luajit_compat, &l);
    vmbuf_puts(&out, p); free(p);

    /* 5. main loop */
    p = vm_gen_dispatch(ops, nops, remap, opts->dispatch_mode, vR, vK, vUV, vPC,
                        opts->luajit_compat, opts->seed ? opts->seed : 1, &l);
    vmbuf_puts(&out, p); free(p);

    /* 6. end execute */
    vmbuf_puts(&out, "end\n\n");

    /* 7. minimal proto builder (no external deps) */
    vmbuf_puts(&out,
        "local function build_proto(chunk)\n"
        "  local subs = {}\n"
        "  local sub_uvs = {}\n"
        "  for i = 1, #chunk.p do\n"
        "    subs[i] = build_proto(chunk.p[i])\n"
        "    sub_uvs[i] = chunk.p[i].upvalues\n"
        "  end\n"
        "  local proto = {\n"
        "    code = chunk.code, k = chunk.k, p = subs, sub_uvs = sub_uvs,\n"
        "    upvalues = chunk.upvalues,\n"
        "    num_params = chunk.num_params,\n"
        "    is_vararg = chunk.is_vararg,\n"
        "    maxstacksize = chunk.maxstacksize\n"
        "  }\n"
        "  return function(upvals) return {proto = proto, upvals = upvals} end\n"
        "end\n\n");

    if (remap) free(remap);

    opts->out = vmbuf_detach(&out, &opts->out_len);
    return 0;
}

void vm_assemble_free(VmAsmOpts *opts) {
    if (opts->out) { free(opts->out); opts->out = NULL; }
    opts->out_len = 0;
}
