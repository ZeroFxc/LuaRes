p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Increase dbg_block_count to 15 to see the decrypt block
s = s.replace('if(dbg_block_count<3){', 'if(dbg_block_count<15){', 1)

open(p, 'w', encoding='utf-8').write(s)
print('increased dbg_block_count to 15')
