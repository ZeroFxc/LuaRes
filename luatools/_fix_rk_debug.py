p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_mainloop.c'
s = open(p, encoding='utf-8').read()
old = '''    vmbuf_printf(&b, "  local function RK(x) if x < 256 then return %s[x] end return %s[x - 255] end\\n", R, K);'''
new = '''    vmbuf_printf(&b, "  local function RK(x) if x < 256 then return %s[x] end local _ki=x-255; if _ki>#%s then io.stderr:write('RK OOB x='..x..' #K='..#%s..'\\\\n') end return %s[_ki] end\\n", R, K, K, K);'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
