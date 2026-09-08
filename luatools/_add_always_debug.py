p = r'E:\LuaRes\luaclib\luac.c'
s = open(p, encoding='utf-8').read()

old = '''        if (valid) {
            memcpy(s, tmp, len);
        }
        free(tmp);'''

new = '''        if (len == 1 && (unsigned char)s[0] >= 0x80) {
            fprintf(stderr, "[LUAC_DBG] orig=%d dec=%d valid=%d encrypted=%d\\n",
                (unsigned char)s[0], (unsigned char)tmp[0], valid, S->encrypted);
        }
        if (valid) {
            memcpy(s, tmp, len);
        }
        free(tmp);'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('debug added')
