p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_util.c'
s = open(p, encoding='utf-8').read()
old = '''                else if (strcmp(idx,"next_ax")==0) vmbuf_printf(b, "%s[code[%s+1][5]+1]", K, PC);'''
new = '''                else if (strcmp(idx,"next_ax")==0) vmbuf_printf(b, "%s[(((code[%s+1][2] or 0)<<18)|(code[%s+1][5] or 0))+1]", K, PC, PC);'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
