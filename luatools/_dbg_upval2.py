p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Disable constant copying - set child sizek to 0
old = '''        /* 复制父函数常量池到子 proto（基本块指令可能引用常量） */
        if (p->sizek > 0) {'''
new = '''        /* DEBUG: skip constant copying */
        if (0 && p->sizek > 0) {'''
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('disabled constants')
