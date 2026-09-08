/*
** vm_asm_api.c - Public API generator
** VM.load(chunk, env) - load table-format bytecode into closure
** VM.run(closure, ...)  - run closure, return results
** VM.exec(chunk, ...)   - load + run
** VM.pack(proto)        - convert luac proto to table format (requires vm_pack)
*/
#include "vm_asm.h"
#include <stdlib.h>

char *vm_gen_api(size_t *len) {
    VmBuf b; vmbuf_init(&b);
    vmbuf_puts(&b,
        "local VM = {}\n\n"
        "function VM.load(chunk, env)\n"
        "  local factory = load_chunk(chunk, env or _G)\n"
        "  local cl = factory({[0] = {open = false, val = env or _G}})\n"
        "  local f = function(...) return execute(cl, ...) end\n"
        "  closure_map[f] = cl\n"
        "  return f\n"
        "end\n\n"
        "function VM.run(closure, ...)\n"
        "  return execute(closure, ...)\n"
        "end\n\n"
        "function VM.exec(chunk, ...)\n"
        "  local closure = VM.load(chunk)\n"
        "  return execute(closure, ...)\n"
        "end\n\n"
        "function VM.pack(proto)\n"
        "  return vm_pack_proto(proto)\n"
        "end\n\n"
        "function VM.pack_source(src, chunkname)\n"
        "  return vm_load(src, chunkname)\n"
        "end\n\n"
        "return VM\n");
    return vmbuf_detach(&b, len);
}
