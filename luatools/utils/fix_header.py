p = r'E:\LuaRes\luaclib\obf_util.h'
s = open(p, encoding='utf-8').read()
marker = 'void obf_adjust_jumps_remove(unsigned int *code, int code_len, int pos, int n);'
addition = marker + """

/* Invalidate cached Lua code table (call after any p->code modification) */
void obf_invalidate_code_cache(lua_State *L, luac_Proto *p);

/* Invalidate all cached Lua tables (code, k, p, lineinfo, etc.) */
void obf_invalidate_all_caches(lua_State *L, luac_Proto *p);
"""
s = s.replace(marker, addition, 1)
open(p, 'w', encoding='utf-8').write(s)
print('done')
