p = r'E:\LuaRes\luaclib\cfg_shuffle.c'
s = open(p, encoding='utf-8').read()

# Fix inserted JMP opcode: 27 -> 30
s = s.replace(
    'new_code[pos] = set_sbx(LUAC_ABC(27, 0, 0, 0), sbx);  /* JMP A=0 */',
    'new_code[pos] = set_sbx(LUAC_ABC(30, 0, 0, 0), sbx);  /* JMP A=0 */'
)

# Fix debug check: op != 27 -> op != 30
s = s.replace(
    'if (instr_offset == 0 || op != 27) {',
    'if (instr_offset == 0 || op != 30) {'
)

open(p, 'w', encoding='utf-8').write(s)
print('done')
