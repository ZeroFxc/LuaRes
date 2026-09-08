p = r'E:\LuaRes\luaclib\vm_asm\vm_embed.c'
s = open(p, encoding='utf-8').read()

# Add debug in rd_string for all strings (not just encrypted)
old = '''    *outlen = len;
    return (char*)raw;
}'''

new = '''    if (len == 1 && raw[0] >= 0x80) {
        FILE *df = fopen("_vm_dbg.txt", "a");
        fprintf(df, "rd_string: len=%zu byte=%d encrypted=%d pos=%zu\\n", len, raw[0], r->encrypted, r->pos);
        fclose(df);
    }
    *outlen = len;
    return (char*)raw;
}'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('debug added')
