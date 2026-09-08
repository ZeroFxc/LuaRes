p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_ops.c'
s = open(p, encoding='utf-8').read()
old = 'local _v={REG:{B}}; local _f=(_v==nil or _v==false); local _m=({C}~=0 and _f) or ({C}==0 and not _f); if _m then {REG:{A}}=_v end; if _m then {NEXT} end'
dbg = 'io.stderr:write("TESTSET pc="..{PC}.." a="..{A}.." b="..{B}.." c="..{C}.." _v="..tostring(_v).." _m="..tostring(_m).."\\n"); io.stderr:flush(); '
new = 'local _v={REG:{B}}; local _f=(_v==nil or _v==false); local _m=({C}~=0 and _f) or ({C}==0 and not _f); ' + dbg + 'if _m then {REG:{A}}=_v end; if _m then {NEXT} end'
if old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('Added debug to TESTSET')
else:
    print('Pattern not found')
    idx = s.find('TESTSET')
    print(repr(s[idx:idx+250]))
