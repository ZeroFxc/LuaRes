p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Minimal child: just RETURN, no upvalues, no constants
s = s.replace(
    '        /* 新 proto 指令：GETUPVAL * next + 基本块 + RETURN */',
    '        /* DEBUG minimal: just RETURN */\n#if 0\n        /* 新 proto 指令：GETUPVAL * next + 基本块 + RETURN */'
)
s = s.replace(
    '        child->code[load_count + block_len] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);',
    '        child->code[load_count + block_len] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);\n#else\n        int total_ins = 1;\n        child->code = malloc(sizeof(unsigned int));\n        child->sizecode = 1;\n        child->code[0] = LUAC_ABC(LUAC_OP_RETURN, 0, 1, 0);\n        (void)load_count; (void)block_len; (void)ext_regs;\n#endif'
)

# No upvalues
s = s.replace(
    '        child->sizeupvalues = next + 1;  /* +1 for _ENV */',
    '        child->sizeupvalues = 0;  /* DEBUG: no upvalues */'
)
s = s.replace(
    '        /* 分配 upvalue：_ENV at 0, external vars at 1..next */',
    '#if 0\n        /* 分配 upvalue：_ENV at 0, external vars at 1..next */'
)
s = s.replace(
    '            child->upval_idx[i + 1] = ext_regs[i];  /* 源寄存器 */\n        }',
    '            child->upval_idx[i + 1] = ext_regs[i];  /* 源寄存器 */\n        }\n#else\n        child->upval_name = NULL; child->upval_name_len = NULL;\n        child->upval_instack = NULL; child->upval_idx = NULL;\n#endif'
)

# No constants
s = s.replace(
    '        /* 复制父函数常量池到子 proto（基本块指令可能引用常量） */',
    '#if 0\n        /* 复制父函数常量池到子 proto（基本块指令可能引用常量） */'
)
# Find the end of the constant copying block and close the #if
s = s.replace(
    '            }\n        }\n\n        /* 创建新 proto */',
    '            }\n        }\n#endif\n\n        /* 创建新 proto */'
)

open(p, 'w', encoding='utf-8').write(s)
print('minimal child with correct JMP')
