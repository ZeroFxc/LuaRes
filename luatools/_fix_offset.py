p = r'E:\LuaRes\luaclib\integrity_check.c'
s = open(p, encoding='utf-8').read()

old = '''        /* sizecode 在字节 24-27 (1-based, 小端序 int) */
        "local __n=__bc:byte(24)|(__bc:byte(25)<<8)|(__bc:byte(26)<<16)|(__bc:byte(27)<<24)\\n"
        "local __h=2166136261\\n"
        /* 指令序列从字节 28 开始，长度 __n*4 */
        "for __i=28,27+__n*4 do\\n"'''

new = '''        /* sizecode 在字节 42-45 (1-based, 小端序 int)
           header=29字节 + source_len=1 + linedefined=4 + lastlinedefined=4 +
           numparams=1 + is_vararg=1 + maxstacksize=1 = 41, sizecode从42开始 */
        "local __n=__bc:byte(42)|(__bc:byte(43)<<8)|(__bc:byte(44)<<16)|(__bc:byte(45)<<24)\\n"
        "local __h=2166136261\\n"
        /* 指令序列从字节 46 开始，长度 __n*4 */
        "for __i=46,45+__n*4 do\\n"'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
