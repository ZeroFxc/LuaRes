p = r'E:\LuaRes\luaclib\cfg_shuffle.c'
s = open(p, encoding='utf-8').read()

# Fix get_sbx: 131072 -> 131071
s = s.replace(
    'static int get_sbx(unsigned int ins) {\n    int bx = (ins >> 14) & 0x3FFFF;\n    return bx - 131072;\n}',
    'static int get_sbx(unsigned int ins) {\n    int bx = (ins >> 14) & 0x3FFFF;\n    return bx - 131071;\n}'
)

# Fix set_sbx: 131072 -> 131071
s = s.replace(
    'static unsigned int set_sbx(unsigned int ins, int sbx) {\n    int bx = sbx + 131072;\n    return (ins & 0xFFF) | ((bx & 0x3FFFF) << 14);\n}',
    'static unsigned int set_sbx(unsigned int ins, int sbx) {\n    int bx = sbx + 131071;\n    return (ins & 0xFFF) | ((bx & 0x3FFFF) << 14);\n}'
)

open(p, 'w', encoding='utf-8').write(s)
print('done')
