p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_ops.c'
s = open(p, encoding='utf-8').read()

old = '''    {"BAND",     20, FMT_ABC,  "{REG:{A}} = {RK:{B}} & {RK:{C}}", "{REG:{A}} = _band({RK:{B}}, {RK:{C}})"},
    {"BOR",      21, FMT_ABC,  "{REG:{A}} = {RK:{B}} | {RK:{C}}", "{REG:{A}} = _bor({RK:{B}}, {RK:{C}})"},
    {"BXOR",     22, FMT_ABC,  "{REG:{A}} = {RK:{B}} ~ {RK:{C}}", "{REG:{A}} = _bxor({RK:{B}}, {RK:{C}})"},
    {"SHL",      23, FMT_ABC,  "{REG:{A}} = {RK:{B}} << {RK:{C}}", "{REG:{A}} = _shl({RK:{B}}, {RK:{C}})"},
    {"SHR",      24, FMT_ABC,  "{REG:{A}} = {RK:{B}} >> {RK:{C}}", "{REG:{A}} = _shr({RK:{B}}, {RK:{C}})"},'''

dbg = "local _b={RK:{B}}; local _c={RK:{C}}; if _b==nil or _c==nil then io.stderr:write('BITOP nil pc='..{PC}..' op=%d a='..{A}..' b='..{B}..' c='..{C}..' Rb='..tostring(_b)..' Rc='..tostring(_c)..'\\\\n'); io.stderr:flush() end; {REG:{A}} = _b %s _c"

new = f'''    {{"BAND",     20, FMT_ABC,  "{dbg % (20, '&')}", "{{REG:{{A}}}} = _band({{RK:{{B}}}}, {{RK:{{C}}}})"}},
    {{"BOR",      21, FMT_ABC,  "{dbg % (21, '|')}", "{{REG:{{A}}}} = _bor({{RK:{{B}}}}, {{RK:{{C}}}})"}},
    {{"BXOR",     22, FMT_ABC,  "{dbg % (22, '~')}", "{{REG:{{A}}}} = _bxor({{RK:{{B}}}}, {{RK:{{C}}}})"}},
    {{"SHL",      23, FMT_ABC,  "{dbg % (23, '<<')}", "{{REG:{{A}}}} = _shl({{RK:{{B}}}}, {{RK:{{C}}}})"}},
    {{"SHR",      24, FMT_ABC,  "{dbg % (24, '>>')}", "{{REG:{{A}}}} = _shr({{RK:{{B}}}}, {{RK:{{C}}}})"}},'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
