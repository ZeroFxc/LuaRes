p = r'E:\LuaRes\luaclib\vm_asm\vm_embed.c'
s = open(p, encoding='utf-8').read()

# Add debug output in vm_embed_generate
old = '''    Reader r = { bc, 0, bc_len, (bc[0] == 0x1A) ? 1 : 0 };
    r.pos = 34;'''

new = '''    Reader r = { bc, 0, bc_len, (bc[0] == 0x1A) ? 1 : 0 };
    r.pos = 34;
    fprintf(stderr, "[vm_embed debug] bc[0]=0x%02X encrypted=%d bc_len=%zu\\n", bc[0], r.encrypted, bc_len);'''

s = s.replace(old, new, 1)

# Add debug in rd_string
old2 = '''    if (r->encrypted && len > 0) {
        unsigned char *tmp = malloc(len);
        memcpy(tmp, raw, len);
        decrypt_string(tmp, len);
        if (is_valid_text(tmp, len)) memcpy(raw, tmp, len);
        free(tmp);
    }'''

new2 = '''    if (r->encrypted && len > 0) {
        unsigned char *tmp = malloc(len);
        memcpy(tmp, raw, len);
        decrypt_string(tmp, len);
        int valid = is_valid_text(tmp, len);
        if (len == 1 && (raw[0] >= 0x80)) {
            fprintf(stderr, "[rd_string debug] len=%zu raw[0]=%d decrypted[0]=%d valid=%d\\n", len, raw[0], tmp[0], valid);
        }
        if (valid) memcpy(raw, tmp, len);
        free(tmp);
    }'''

s = s.replace(old2, new2, 1)
open(p, 'w', encoding='utf-8').write(s)
print('debug added')
