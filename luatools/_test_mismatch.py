p = r'E:\LuaRes\luaclib\integrity_check.c'
s = open(p, encoding='utf-8').read()
# 故意把哈希值+1，让校验失败
s = s.replace('unsigned int hash = hash_code(p);', 'unsigned int hash = hash_code(p) + 1; // TEST: force mismatch', 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
