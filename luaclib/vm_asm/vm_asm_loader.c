/*
** vm_asm_loader.c - Bytecode table loader generator
** Loads the custom table-format bytecode into executable closures.
*/
#include "vm_asm.h"
#include <stdlib.h>

char *vm_gen_loader(size_t *len) {
    VmBuf b; vmbuf_init(&b);
    vmbuf_puts(&b,
        "-- Bytecode table loader (generated)\n"
        "local function load_chunk(chunk, env)\n"
        "  local k = {}\n"
        "  for i, kc in ipairs(chunk.k) do\n"
        "    if kc.t == 'n' then k[i] = nil\n"
        "    elseif kc.t == 'b' then k[i] = kc.v\n"
        "    elseif kc.t == 'i' then k[i] = math.tointeger(kc.v) or kc.v\n"
        "    elseif kc.t == 'f' then k[i] = kc.v + 0.0\n"
        "    elseif kc.t == 's' then k[i] = kc.v end\n"
        "  end\n"
        "  local subs = {}\n"
        "  local sub_uvs = {}\n"
        "  for i, sp in ipairs(chunk.p) do\n"
        "    subs[i] = load_chunk(sp, env)\n"
        "    sub_uvs[i] = sp.upvalues\n"
        "  end\n"
        "  local proto = {\n"
        "    code = chunk.code, k = k, p = subs, sub_uvs = sub_uvs,\n"
        "    upvalues = chunk.upvalues,\n"
        "    num_params = chunk.num_params,\n"
        "    is_vararg = chunk.is_vararg,\n"
        "    maxstacksize = chunk.maxstacksize\n"
        "  }\n"
        "  return function(upvals) return {proto = proto, upvals = upvals} end\n"        "end\n\n");
    return vmbuf_detach(&b, len);
}
