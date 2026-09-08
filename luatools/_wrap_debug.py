import re

# Fix vm_embed.c - wrap debug in #if VM_EMBED_DEBUG
p1 = r'E:\LuaRes\luaclib\vm_asm\vm_embed.c'
s1 = open(p1, encoding='utf-8').read()

# Add macro define at top after includes
s1 = s1.replace(
    '#include <stdint.h>\n',
    '#include <stdint.h>\n\n/* Debug macro: compile with -DVM_EMBED_DEBUG=1 to enable */\n#ifndef VM_EMBED_DEBUG\n#define VM_EMBED_DEBUG 0\n#endif\n'
)

# Wrap line 82 debug
s1 = s1.replace(
    '            { FILE *df = fopen("_vm_dbg.txt", "a"); fprintf(df, "rd_string len=%zu raw[0]=%d dec[0]=%d valid=%d\\n", len, raw[0], tmp[0], valid); fclose(df); }',
    '#if VM_EMBED_DEBUG\n            { FILE *df = fopen("_vm_dbg.txt", "a"); fprintf(df, "rd_string len=%zu raw[0]=%d dec[0]=%d valid=%d\\n", len, raw[0], tmp[0], valid); fclose(df); }\n#endif'
)

# Wrap line 88 debug (the len==1 high byte debug)
old88 = '''    if (len == 1 && raw[0] >= 0x80) {
        FILE *df = fopen("_vm_dbg.txt", "a");
        fprintf(df, "rd_string: len=%zu byte=%d encrypted=%d pos=%zu\\n", len, raw[0], r->encrypted, r->pos);
        fclose(df);
    }'''
new88 = '''#if VM_EMBED_DEBUG
    if (len == 1 && raw[0] >= 0x80) {
        FILE *df = fopen("_vm_dbg.txt", "a");
        fprintf(df, "rd_string: len=%zu byte=%d encrypted=%d pos=%zu\\n", len, raw[0], r->encrypted, r->pos);
        fclose(df);
    }
#endif'''
s1 = s1.replace(old88, new88)

# Wrap line 235 debug
s1 = s1.replace(
    '    { FILE *df = fopen("_vm_dbg.txt", "w"); fprintf(df, "bc[0]=0x%02X encrypted=%d bc_len=%zu\\n", bc[0], r.encrypted, bc_len); fclose(df); }',
    '#if VM_EMBED_DEBUG\n    { FILE *df = fopen("_vm_dbg.txt", "w"); fprintf(df, "bc[0]=0x%02X encrypted=%d bc_len=%zu\\n", bc[0], r.encrypted, bc_len); fclose(df); }\n#endif'
)

open(p1, 'w', encoding='utf-8').write(s1)
print('vm_embed.c debug wrapped')

# Fix luac.c - wrap debug in #if LUACLIB_DEBUG
p2 = r'E:\LuaRes\luaclib\luac.c'
s2 = open(p2, encoding='utf-8').read()

# Check if LUACLIB_DEBUG already defined
if 'LUACLIB_DEBUG' not in s2.split('LoadString')[0]:
    # Add after first include
    s2 = s2.replace(
        '#include "luac.h"',
        '#include "luac.h"\n\n/* Debug macro: compile with -DLUACLIB_DEBUG=1 to enable */\n#ifndef LUACLIB_DEBUG\n#define LUACLIB_DEBUG 0\n#endif'
    )

# Wrap the len==1 debug
old_luac = '''        if (len == 1 && (unsigned char)s[0] >= 0x80) {
            FILE *df = fopen("_luac_dbg.txt", "a");
            fprintf(df, "LoadString: len=%zu orig=%d dec=%d valid=%d encrypted=%d\\n", len, (unsigned char)s[0], (unsigned char)tmp[0], valid, S->encrypted);
            fclose(df);
        }'''
new_luac = '''#if LUACLIB_DEBUG
        if (len == 1 && (unsigned char)s[0] >= 0x80) {
            FILE *df = fopen("_luac_dbg.txt", "a");
            fprintf(df, "LoadString: len=%zu orig=%d dec=%d valid=%d encrypted=%d\\n", len, (unsigned char)s[0], (unsigned char)tmp[0], valid, S->encrypted);
            fclose(df);
        }
#endif'''
s2 = s2.replace(old_luac, new_luac)

open(p2, 'w', encoding='utf-8').write(s2)
print('luac.c debug wrapped')
