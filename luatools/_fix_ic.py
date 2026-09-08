p = r'E:\LuaRes\luaclib\integrity_check.c'
s = open(p, encoding='utf-8').read()

old = """    /* 其他字段设为 NULL/0 */
    copy->lineinfo = NULL;
    copy->locvars = NULL;
    copy->upvalues = NULL;
    copy->source = NULL;
    copy->code_tbl = LUA_NOREF;
    copy->k_tbl = LUA_NOREF;
    copy->p_tbl = LUA_NOREF;
    copy->lineinfo_tbl = LUA_NOREF;
    copy->locvars_tbl = LUA_NOREF;
    copy->upvalues_tbl = LUA_NOREF;"""

new = """    /* debug 字段设为 NULL/0（校验函数不需要调试信息） */
    copy->lineinfo = NULL;
    copy->locvar_name = NULL;
    copy->locvar_name_len = NULL;
    copy->locvar_startpc = NULL;
    copy->locvar_endpc = NULL;
    copy->upval_name = NULL;
    copy->upval_name_len = NULL;
    copy->upval_instack = NULL;
    copy->upval_idx = NULL;
    copy->source = NULL;
    copy->source_len = 0;
    copy->sizelineinfo = 0;
    copy->sizelocvars = 0;
    copy->sizeupvalues = 0;
    /* cached Lua tables 设为 LUA_NOREF */
    copy->code_tbl = LUA_NOREF;
    copy->k_tbl = LUA_NOREF;
    copy->p_tbl = LUA_NOREF;
    copy->lineinfo_tbl = LUA_NOREF;
    copy->locvars_tbl = LUA_NOREF;
    copy->upvalues_tbl = LUA_NOREF;"""

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
