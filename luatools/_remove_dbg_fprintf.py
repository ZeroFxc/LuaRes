p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()

# Remove always-on fprintf at line 184-190
old1 = '''    if (size > 0 && size < 255) {
        size_t dbg_len = size - 1;
        if (dbg_len == 1) {
            /* peek at next byte */
            fprintf(stderr, "[LUAC_ENTRY] size=%zu encrypted=%d next_byte=%d\\n", size, S->encrypted, (int)S->buf[S->pos]);
        }
    }
    int used_longfmt'''
new1 = '''    int used_longfmt'''
s = s.replace(old1, new1, 1)

# Remove always-on fprintf at line 227-230
old2 = '''        if (len == 1 && (unsigned char)s[0] >= 0x80) {
            fprintf(stderr, "[LUAC_DBG] orig=%d dec=%d valid=%d encrypted=%d\\n",
                (unsigned char)s[0], (unsigned char)tmp[0], valid, S->encrypted);
        }
        if (valid) {'''
new2 = '''        if (valid) {'''
s = s.replace(old2, new2, 1)

open(p, 'w', encoding='utf-8').write(s)
print('removed always-on fprintf debug code from luac.c')
