p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_util.c'
s = open(p, encoding='utf-8').read()

old = '''                if (strcmp(idx,"extra")==0) vmbuf_printf(b, "%s[extra]", K);
                else vmbuf_printf(b, "%s[%s+1]", K, idx);'''
new = '''                if (strcmp(idx,"extra")==0) vmbuf_printf(b, "%s[extra]", K);
                else if (strcmp(idx,"next_ax")==0) vmbuf_printf(b, "%s[code[%s+1][5]+1]", K, PC);
                else vmbuf_printf(b, "%s[%s+1]", K, idx);'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('next_ax placeholder added')
