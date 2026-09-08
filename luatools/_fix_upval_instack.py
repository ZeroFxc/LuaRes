p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

old = '''    child->sizeupvalues=next+1;
    child->upvalues=malloc(sizeof(luac_Upval)*child->sizeupvalues);
    child->upvalues[0].instack=0;
    child->upvalues[0].idx=0;
    for(int i=0;i<next;i++){
        child->upvalues[i+1].instack=0;
        child->upvalues[i+1].idx=ext_regs[i];
    }'''

new = '''    child->sizeupvalues=next+1;
    child->upvalues=malloc(sizeof(luac_Upval)*child->sizeupvalues);
    child->upvalues[0].instack=0;
    child->upvalues[0].idx=0;
    for(int i=0;i<next;i++){
        child->upvalues[i+1].instack=1;
        child->upvalues[i+1].idx=ext_regs[i];
    }'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed upvalue instack: external vars are parent locals (instack=1)')
