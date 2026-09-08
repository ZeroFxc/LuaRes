p = r'E:\LuaRes\luaclib\vm_asm\vm_embed.c'
s = open(p, encoding='utf-8').read()
old = '''        else if (c < 0x20 || c >= 0x7F) {
            char tmp[8]; snprintf(tmp, sizeof(tmp), "\\%03d", c); buf_str(b, tmp);
        } else buf_char(b, (char)c);'''
new = '''        else if (c < 0x20) {
            char tmp[8]; snprintf(tmp, sizeof(tmp), "\\%03d", c); buf_str(b, tmp);
        } else buf_char(b, (char)c);'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
