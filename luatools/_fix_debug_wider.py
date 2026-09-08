p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_mainloop.c'
s = open(p, encoding='utf-8').read()
old = '''    vmbuf_printf(&b, "    if %s >= 5450 and %s <= 5470 then io.stderr:write('DBG pc='..%s..' op='..(ins[1] or 'nil')..' a='..(ins[2] or 'nil')..' b='..(ins[3] or 'nil')..' c='..(ins[4] or 'nil')..' sbx='..((ins[5] or 0)-131071)..' R250='..tostring(%s[250])..'\\\\n') end\\n", PC, PC, PC, R);'''
new = '''    vmbuf_printf(&b, "    if %s >= 5430 and %s <= 5470 then io.stderr:write('DBG pc='..%s..' op='..(ins[1] or 'nil')..' a='..(ins[2] or 'nil')..' b='..(ins[3] or 'nil')..' c='..(ins[4] or 'nil')..' sbx='..((ins[5] or 0)-131071)..'\\\\n') end\\n", PC, PC, PC);'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
