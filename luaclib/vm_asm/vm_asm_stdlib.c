/*
** vm_asm_stdlib.c - Standard library exposure generator
** Exposes host Lua stdlib to VM code. Also provides vm_load for
** loading source/bytecode into the VM's own table format (for self-hosting).
*/
#include "vm_asm.h"
#include <stdlib.h>

char *vm_gen_stdlib(int include_debug, size_t *len) {
    VmBuf b; vmbuf_init(&b);

    vmbuf_puts(&b,
        "-- Standard library bridge (generated)\n"
        "-- VM code runs with host _G as default env, so all stdlib is available.\n"
        "-- vm_pack_proto: convert luac.undump proto to VM table format\n"
        "local function vm_pack_proto(proto)\n"
        "  local chunk = {\n"
        "    num_params = proto.numparams or 0,\n"
        "    is_vararg = proto.is_vararg or 0,\n"
        "    maxstacksize = proto.maxstacksize or 2,\n"
        "    code = {}, k = {}, p = {}, upvalues = {}\n"
        "  }\n"
        "  for i = 1, proto.sizecode do\n"
        "    local ins = proto.code[i]\n"
        "    local op = ins & 0x3F\n"
        "    local a = (ins >> 6) & 0xFF\n"
        "    local cc = (ins >> 14) & 0x1FF\n"
        "    local b = (ins >> 23) & 0x1FF\n"
        "    local bx = ins >> 14\n"
        "    chunk.code[i] = {op, a, b, cc, bx, bx - 131071}\n"
        "  end\n"
        "  for i = 1, proto.sizek do\n"
        "    local v = proto.k[i]\n"
        "    local t = type(v)\n"
        "    if t == 'nil' then chunk.k[i] = {t='n'}\n"
        "    elseif t == 'boolean' then chunk.k[i] = {t='b', v=v}\n"
        "    elseif t == 'number' then\n"
        "      if math.tointeger(v) == v then chunk.k[i] = {t='i', v=v}\n"
        "      else chunk.k[i] = {t='f', v=v} end\n"
        "    elseif t == 'string' then chunk.k[i] = {t='s', v=v}\n"
        "    else chunk.k[i] = {t='n'} end\n"
        "  end\n"
        "  for i = 1, proto.sizep do\n"
        "    chunk.p[i] = vm_pack_proto(proto.p[i])\n"
        "  end\n"
        "  if proto.upvalues then\n"
        "    for i = 1, #proto.upvalues do\n"
        "      local uv = proto.upvalues[i]\n"
        "      chunk.upvalues[i] = {instack = uv.instack or 0, idx = uv.idx or 0}\n"
        "    end\n"
        "  end\n"
        "  return chunk\n"
        "end\n\n"
        "-- Additional VM-specific load function:\n"
        "local function vm_load(src, chunkname)\n"
        "  local f, err = load(src, chunkname)\n"
        "  if not f then return nil, err end\n"
        "  local bc = string.dec(string.dump(f, true))\n"
        "  local proto = luac.undump(bc, true)\n"
        "  return vm_pack_proto(proto)\n"
        "end\n\n");

    if (include_debug) {
        vmbuf_puts(&b,
            "-- Debug library bridge\n"
            "local vm_debug = {\n"
            "  traceback = debug.traceback,\n"
            "  getinfo = debug.getinfo,\n"
            "  getlocal = debug.getlocal,\n"
            "  setlocal = debug.setlocal,\n"
            "  getupvalue = debug.getupvalue,\n"
            "  setupvalue = debug.setupvalue,\n"
            "  sethook = function() end,\n"
            "  gethook = function() return nil end,\n"
            "}\n\n");
    }

    return vmbuf_detach(&b, len);
}
