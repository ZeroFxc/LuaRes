p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_mainloop.c'
s = open(p, encoding='utf-8').read()
old = '''    vmbuf_printf(&b, "  local function RK(x) if x < 256 then local _v=%s[x]; if _v==nil then io.stderr:write('RK nil reg x='..x..' pc='..%s..' op='..(ins and ins[1] or '?')..'\\\\n') end return _v end local _ki=x-255; if _ki>#%s then io.stderr:write('RK OOB x='..x..' #K='..#%s..'\\\\n') end return %s[_ki] end\\n", R, PC, K, K, K);'''
new = '''    vmbuf_printf(&b, "  local function RK(x) if x < 256 then local _v=%s[x]; if _v==nil then io.stderr:write('RK nil reg x='..x..' pc='..%s..' #code='..#code..' ins='..tostring(ins)..' op='..(ins and ins[1] or '?')..' a='..(ins and ins[2] or '?')..' b='..(ins and ins[3] or '?')..' c='..(ins and ins[4] or '?')..'\\\\n') end return _v end local _ki=x-255; if _ki>#%s then io.stderr:write('RK OOB x='..x..' #K='..#%s..'\\\\n') end return %s[_ki] end\\n", R, PC, K, K, K);'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
