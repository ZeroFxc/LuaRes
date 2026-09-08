p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''    int n=0;
    if(p->p)for(int i=0;i<p->sizep;i++)
        n+=promote_in_proto(L,p->p[i],count>3?count/2:3);
    n+=promote_in_proto(L,p,count);'''

new = '''    int n=0;
    /* 只处理主 proto，不处理子 proto：子 proto 函数体被 IIFE 包装后返回值无法传回 */
    n+=promote_in_proto(L,p,count);'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('disabled sub-proto processing in upvalue_promote')
