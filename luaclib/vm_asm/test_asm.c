#include <stdio.h>
#include <stdlib.h>
#include "vm_asm.h"

int main(int argc, char **argv) {
    VmAsmOpts opts = {0};
    opts.include_coroutine = 1;
    opts.include_debug = 1;
    if (argc > 1 && argv[1][0] == 'r') {
        opts.remap = 1;
        opts.obfuscate_names = 1;
        opts.seed = 42;
    }
    if (vm_assemble(&opts) != 0) {
        fprintf(stderr, "assembly failed\n");
        return 1;
    }
    const char *outpath = (argc > 2) ? argv[2] : "E:/LuaRes/luatools/vm_gen.lua";
    FILE *f = fopen(outpath, "w");
    if (!f) { perror("fopen"); return 1; }
    fwrite(opts.out, 1, opts.out_len, f);
    fclose(f);
    printf("Generated %s: %zu bytes\n", outpath, opts.out_len);
    vm_assemble_free(&opts);
    return 0;
}
