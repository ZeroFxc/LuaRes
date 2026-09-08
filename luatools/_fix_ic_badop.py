p = r'E:\LuaRes\luaclib\integrity_check.c'
s = open(p, encoding='utf-8').read()

# 1. 修改校验函数源码：校验失败时执行标记常量，编译后替换成非法 opcode
old_src = '''    snprintf(src, sizeof(src),
        "local __f=debug.getinfo(2,'f').func\\n"
        "local __bc=string.dump(__f,true)\\n"
        "local __h=2166136261\\n"
        "for __i=1,#__bc do\\n"
        "  __h=((__h~__bc:byte(__i))*16777619)&4294967295\\n"
        "end\\n"
        "if __h~=%u then\\n"
        "  while true do end\\n"
        "end\\n",
        hash_val);'''

new_src = '''    snprintf(src, sizeof(src),
        "local __f=debug.getinfo(2,'f').func\\n"
        "local __bc=string.dump(__f,true)\\n"
        "local __h=2166136261\\n"
        "for __i=1,#__bc do\\n"
        "  __h=((__h~__bc:byte(__i))*16777619)&4294967295\\n"
        "end\\n"
        "if __h~=%u then\\n"
        "  local __trigger__=32767\\n"
        "end\\n",
        hash_val);'''

s = s.replace(old_src, new_src, 1)

# 2. 在深拷贝后、返回前，找到标记常量并替换成非法 opcode
old_return = '''    lua_settop(L, top);
    return copy;
}'''

new_return = '''    /* 找到标记常量 32767，把加载它的 LOADK 指令替换成非法 opcode (op=47) */
    for (int i = 0; i < copy->sizek; i++) {
        if (copy->k_tag[i] == LUA_TNUMBER && copy->k_num[i] == 32767.0) {
            for (int j = 0; j < copy->sizecode; j++) {
                unsigned int ins = copy->code[j];
                int op = ins & 0x3F;
                int bx = (ins >> 14) & 0x3FFFF;
                if (op == 1 /* LOADK */ && bx == i) {
                    copy->code[j] = 47; /* 非法 opcode，VM 执行会崩溃 */
                    break;
                }
            }
            break;
        }
    }

    lua_settop(L, top);
    return copy;
}'''

s = s.replace(old_return, new_return, 1)

open(p, 'w', encoding='utf-8').write(s)
print('done')
