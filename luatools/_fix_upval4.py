p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''        int Rtmp = old_max;
        obf_ensure_stack(p, old_max + 1);'''

new = '''        int Rtmp = old_max;
        /* 子函数调用时寄存器位于父栈帧 Rtmp+1 起，需预留 child->maxstacksize */
        obf_ensure_stack(p, Rtmp + 1 + child->maxstacksize);'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('fixed maxstacksize')
