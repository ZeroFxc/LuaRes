/*
** vm_asm_mainloop.c - Main execution loop generator
** Generates the instruction dispatch loop from the opcode table.
*/
#include "vm_asm.h"
#include <stdlib.h>
#include <string.h>

char *vm_gen_mainloop(const VmOp *ops, int nops, const int *remap,
                      const char *R, const char *K, const char *UV,
                      const char *PC, int luajit_compat, size_t *len) {
    VmBuf b; vmbuf_init(&b);

    vmbuf_printf(&b, "  local function RK(x) if x < 256 then return %s[x] end return %s[x - 255] end\n", R, K);
    vmbuf_printf(&b, "  while %s <= #code do\n", PC);
    vmbuf_printf(&b, "    local ins = code[%s]\n", PC);
#if VM_ASM_DEBUG
    vmbuf_printf(&b, "    if %s >= 5430 and %s <= 5470 then io.stderr:write('DBG pc='..%s..' op='..(ins[1] or 'nil')..' a='..(ins[2] or 'nil')..' b='..(ins[3] or 'nil')..' c='..(ins[4] or 'nil')..' sbx='..((ins[5] or 0)-131071)..'\\n') end\n", PC, PC, PC);
#endif
    vmbuf_printf(&b, "    local op = ins[1]\n");
    vmbuf_printf(&b, "    local a = ins[2] or 0\n");
    vmbuf_printf(&b, "    local b = ins[3] or 0\n");
    vmbuf_printf(&b, "    local c = ins[4] or 0\n");
    vmbuf_printf(&b, "    local bx = ins[5] or 0\n");
    vmbuf_printf(&b, "    local sbx = bx - 131071\n");
    vmbuf_printf(&b, "    if false then\n");

    for (int i = 0; i < nops; i++) {
        const VmOp *op = &ops[i];
        const char *body = (luajit_compat && op->body_compat) ? op->body_compat : op->body;
        if (!body) continue;
        int opcode = remap ? remap[op->op] : op->op;
        vmbuf_printf(&b, "    elseif op == %d then\n", opcode, op->name);
        vmbuf_puts(&b, "      ");
        vm_emit_body(&b, body, R, K, UV, PC, "a", "b", "c", "bx", "sbx");
        vmbuf_putc(&b, '\n');
    }

    vmbuf_printf(&b, "    end\n");
    vmbuf_printf(&b, "    %s = %s + 1\n", PC, PC);
    vmbuf_puts(&b, "  end\n");
    vmbuf_printf(&b, "  closeuv(0)\n");

    return vmbuf_detach(&b, len);
}
