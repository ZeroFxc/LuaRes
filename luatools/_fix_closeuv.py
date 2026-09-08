p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_runtime.c'
s = open(p, encoding='utf-8').read()
old = '        "  local function docall(a, b, c)\\n"\n        "    closeuv(0)\\n"\n        "    local func = %s[a]\\n"'
new = '        "  local function docall(a, b, c)\\n"\n        "    local func = %s[a]\\n"'
if old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('Fixed: removed closeuv(0) from docall')
else:
    print('Pattern not found!')
    # Show context around docall
    idx = s.find('docall(a, b, c)')
    if idx >= 0:
        print(repr(s[idx:idx+200]))
