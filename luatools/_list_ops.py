import re
s = open(r'E:\LuaRes\luaclib\vm_asm\vm_asm_ops.c', encoding='utf-8').read()
entries = re.findall(r'\{"(\w+)",\s*(\d+),\s*(\w+)', s)
print('Total opcodes:', len(entries))
for name, op, fmt in entries:
    print(f'  {int(op):2d} {name:12s} {fmt}')
std = ['MOVE','LOADK','LOADKX','LOADBOOL','LOADNIL','GETUPVAL','GETTABUP','GETTABLE','SETTABUP','SETUPVAL','SETTABLE','NEWTABLE','SELF','ADD','SUB','MUL','MOD','POW','DIV','IDIV','BAND','BOR','BXOR','SHL','SHR','UNM','BNOT','NOT','LEN','CONCAT','JMP','EQ','LT','LE','TEST','TESTSET','CALL','TAILCALL','RETURN','FORLOOP','FORPREP','TFORCALL','TFORLOOP','SETLIST','CLOSURE','VARARG','EXTRAARG']
supported = set(name for name,_,_ in entries)
missing = [x for x in std if x not in supported]
print()
print('Missing standard opcodes:', missing)
