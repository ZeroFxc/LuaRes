p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Remove SELF from the combined list
old = '''        case LUAC_OP_GETTABLE:case LUAC_OP_NEWTABLE:case LUAC_OP_SELF:
        case LUAC_OP_ADD:case LUAC_OP_SUB:case LUAC_OP_MUL:'''
new = '''        case LUAC_OP_GETTABLE:case LUAC_OP_NEWTABLE:
        case LUAC_OP_ADD:case LUAC_OP_SUB:case LUAC_OP_MUL:'''
s = s.replace(old, new, 1)

open(p, 'w', encoding='utf-8').write(s)
print('removed SELF from combined list')
