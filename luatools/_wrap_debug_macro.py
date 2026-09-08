p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_ops.c'
s = open(p, encoding='utf-8').read()

# LOADKX: debug version -> #if VM_ASM_DEBUG / #else / #endif
old_loadkx = '''    {"LOADKX",   2,  FMT_AB,   "local _nx=code[{PC}+1]; local _ax=(_nx[2] or 0)|((_nx[5] or 0)<<8); io.stderr:write('LOADKX pc='..{PC}..' a='..{A}..' nx_a='..(_nx[2] or 0)..' nx_bx='..(_nx[5] or 0)..' ax='.._ax..' #K='..#K..'\\\\n'); io.stderr:flush(); {REG:{A}}=K[_ax+1]; {NEXT}", NULL},'''
new_loadkx = '''#if VM_ASM_DEBUG
    {"LOADKX",   2,  FMT_AB,   "local _nx=code[{PC}+1]; local _ax=(_nx[2] or 0)|((_nx[5] or 0)<<8); io.stderr:write('LOADKX pc='..{PC}..' a='..{A}..' nx_a='..(_nx[2] or 0)..' nx_bx='..(_nx[5] or 0)..' ax='.._ax..' #K='..#K..'\\\\n'); io.stderr:flush(); {REG:{A}}=K[_ax+1]; {NEXT}", NULL},
#else
    {"LOADKX",   2,  FMT_AB,   "local _nx=code[{PC}+1]; {REG:{A}}=K[(_nx[2] or 0)|((_nx[5] or 0)<<8)+1]; {NEXT}", NULL},
#endif'''
s = s.replace(old_loadkx, new_loadkx, 1)

# Bitwise ops: debug version with nil check -> #if VM_ASM_DEBUG / #else / #endif
bitops = [
    ('BAND', 20, '&', '_band'),
    ('BOR', 21, '|', '_bor'),
    ('BXOR', 22, '~', '_bxor'),
    ('SHL', 23, '<<', '_shl'),
    ('SHR', 24, '>>', '_shr'),
]
for name, opnum, luop, cfunc in bitops:
    old = f'''    {{"{name}",     {opnum}, FMT_ABC,  "local _b={{RK:{{B}}}}; local _c={{RK:{{C}}}}; if _b==nil or _c==nil then io.stderr:write('BITOP nil pc='..{{PC}}..' op={opnum} a='..{{A}}..' b='..{{B}}..' c='..{{C}}..' Rb='..tostring(_b)..' Rc='..tostring(_c)..'\\\\n'); io.stderr:flush() end; {{REG:{{A}}}} = _b {luop} _c", "{{REG:{{A}}}} = {cfunc}({{RK:{{B}}}}, {{RK:{{C}}}})"}},'''
    new = f'''#if VM_ASM_DEBUG
    {{"{name}",     {opnum}, FMT_ABC,  "local _b={{RK:{{B}}}}; local _c={{RK:{{C}}}}; if _b==nil or _c==nil then io.stderr:write('BITOP nil pc='..{{PC}}..' op={opnum} a='..{{A}}..' b='..{{B}}..' c='..{{C}}..' Rb='..tostring(_b)..' Rc='..tostring(_c)..'\\\\n'); io.stderr:flush() end; {{REG:{{A}}}} = _b {luop} _c", "{{REG:{{A}}}} = {cfunc}({{RK:{{B}}}}, {{RK:{{C}}}})"}},
#else
    {{"{name}",     {opnum}, FMT_ABC,  "{{REG:{{A}}}} = {{RK:{{B}}}} {luop} {{RK:{{C}}}}", "{{REG:{{A}}}} = {cfunc}({{RK:{{B}}}}, {{RK:{{C}}}})"}},
#endif'''
    s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('fixed vm_asm_ops.c')

# Now fix vm_asm_mainloop.c - wrap the pc range debug output
p2 = r'E:\LuaRes\luaclib\vm_asm\vm_asm_mainloop.c'
s2 = open(p2, encoding='utf-8').read()
old_dbg = '''    if pc >= 5430 and pc <= 5470 then io.stderr:write('DBG pc='..pc..' op='..(ins[1] or 'nil')..' a='..(ins[2] or 'nil')..' b='..(ins[3] or 'nil')..' c='..(ins[4] or 'nil')..' sbx='..((ins[5] or 0)-131071)..'\\\\n') end'''
new_dbg = '''#if VM_ASM_DEBUG
    if pc >= 5430 and pc <= 5470 then io.stderr:write('DBG pc='..pc..' op='..(ins[1] or 'nil')..' a='..(ins[2] or 'nil')..' b='..(ins[3] or 'nil')..' c='..(ins[4] or 'nil')..' sbx='..((ins[5] or 0)-131071)..'\\\\n') end
#endif'''
s2 = s2.replace(old_dbg, new_dbg, 1)
open(p2, 'w', encoding='utf-8').write(s2)
print('fixed vm_asm_mainloop.c')
