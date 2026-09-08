p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_mainloop.c'
s = open(p, encoding='utf-8').read()
# Revert RK debug to simple version
old_rk = '''    vmbuf_printf(&b, "  local function RK(x) if x < 256 then local _v=%s[x]; if _v==nil then io.stderr:write('RK nil reg x='..x..' pc='..%s..' #code='..#code..' ins='..tostring(ins)..' op='..(ins and ins[1] or '?')..' a='..(ins and ins[2] or '?')..' b='..(ins and ins[3] or '?')..' c='..(ins and ins[4] or '?')..'\\\\n') end return _v end local _ki=x-255; if _ki>#%s then io.stderr:write('RK OOB x='..x..' #K='..#%s..'\\\\n') end return %s[_ki] end\\n", R, PC, K, K, K);'''
new_rk = '''    vmbuf_printf(&b, "  local function RK(x) if x < 256 then return %s[x] end return %s[x - 255] end\\n", R, K);'''
s = s.replace(old_rk, new_rk, 1)
# Add debug in main loop: print instruction when pc >= 5460 and pc <= 5470
old_loop = '''    vmbuf_printf(&b, "    local ins = code[%s]\\n", PC);'''
new_loop = '''    vmbuf_printf(&b, "    local ins = code[%s]\\n", PC);
    vmbuf_printf(&b, "    if %s >= 5460 and %s <= 5470 then io.stderr:write('DBG pc='..%s..' op='..(ins[1] or 'nil')..' a='..(ins[2] or 'nil')..' b='..(ins[3] or 'nil')..' c='..(ins[4] or 'nil')..' bx='..(ins[5] or 'nil')..' R250='..tostring(%s[250])..'\\\\n') end\\n", PC, PC, PC, R);'''
s = s.replace(old_loop, new_loop, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
