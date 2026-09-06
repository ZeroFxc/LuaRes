#!/usr/bin/env python3
"""Fix luac.c string truncation bug: add length fields for all strings,
DumpString uses explicit length instead of strlen, LoadString returns length."""
import sys

path = r'E:\LuaRes\luaclib\luac.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

replacements = []

# 1. Struct: add length fields
replacements.append((
    '''    char **k_str;
    double *k_num;
    int *k_bool;
    /* debug */
    int *lineinfo;
    char **locvar_name;
    int *locvar_startpc;
    int *locvar_endpc;
    char **upval_name;
    unsigned char *upval_instack;
    unsigned char *upval_idx;''',
    '''    char **k_str;
    int *k_str_len;
    double *k_num;
    int *k_bool;
    /* debug */
    int *lineinfo;
    char **locvar_name;
    int *locvar_name_len;
    int *locvar_startpc;
    int *locvar_endpc;
    char **upval_name;
    int *upval_name_len;
    unsigned char *upval_instack;
    unsigned char *upval_idx;'''
))

# 2. Struct: add source_len
replacements.append((
    '''    char *source;
    /* cached Lua tables''',
    '''    char *source;
    int source_len;
    /* cached Lua tables'''
))

# 3. Add luac_strndup after luac_strdup
replacements.append((
    '''static char *luac_strdup(const char *s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char *p = luac_alloc(len);
    memcpy(p, s, len);
    return p;
}''',
    '''static char *luac_strdup(const char *s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char *p = luac_alloc(len);
    memcpy(p, s, len);
    return p;
}

static char *luac_strndup(const char *s, size_t len) {
    if (!s) return NULL;
    char *p = luac_alloc(len + 1);
    memcpy(p, s, len);
    p[len] = '\\0';
    return p;
}'''
))

# 4. DumpString: add len parameter
replacements.append((
    '''static void DumpString(DumpState *D, const char *s) {
    if (!s) {
        DumpByte(D, 0);
        return;
    }
    size_t len = strlen(s);
    if (len == 0) {
        g_dump_empty_str++;''',
    '''static void DumpString(DumpState *D, const char *s, size_t len) {
    if (!s) {
        DumpByte(D, 0);
        return;
    }
    if (len == 0) {
        g_dump_empty_str++;'''
))

# 5. DumpString debug print: remove %s (may contain 0 bytes)
replacements.append((
    '''    fprintf(stderr, "[luac] DumpString: len=%zu '%s'\\n", len, s);''',
    '''    fprintf(stderr, "[luac] DumpString: len=%zu\\n", len);'''
))

# 6. LoadString: add out_len parameter
replacements.append((
    '''static char *LoadString(UndumpState *S) {
    size_t size = LoadByte(S);''',
    '''static char *LoadString(UndumpState *S, size_t *out_len) {
    size_t size = LoadByte(S);'''
))

# 7. LoadString: store output length before return
replacements.append((
    '''    if (size == 0) return NULL;
    size_t len = size - 1;  /* size includes null terminator, but only len bytes stored */''',
    '''    if (size == 0) { if (out_len) *out_len = 0; return NULL; }
    size_t len = size - 1;  /* size includes null terminator, but only len bytes stored */
    if (out_len) *out_len = len;'''
))

# 8. LoadConstants: allocate k_str_len
replacements.append((
    '''        f->k_tag = luac_alloc(sizeof(int) * f->sizek);
        f->k_str = luac_alloc(sizeof(char *) * f->sizek);
        f->k_num = luac_alloc(sizeof(double) * f->sizek);
        f->k_bool = luac_alloc(sizeof(int) * f->sizek);''',
    '''        f->k_tag = luac_alloc(sizeof(int) * f->sizek);
        f->k_str = luac_alloc(sizeof(char *) * f->sizek);
        f->k_str_len = luac_alloc(sizeof(int) * f->sizek);
        f->k_num = luac_alloc(sizeof(double) * f->sizek);
        f->k_bool = luac_alloc(sizeof(int) * f->sizek);'''
))

# 9. LoadConstants: init k_str_len[i]
replacements.append((
    '''            f->k_str[i] = NULL;
            f->k_num[i] = 0;
            f->k_bool[i] = 0;''',
    '''            f->k_str[i] = NULL;
            f->k_str_len[i] = 0;
            f->k_num[i] = 0;
            f->k_bool[i] = 0;'''
))

# 10. LoadConstants: string case - store length
replacements.append((
    '''                case LUA_TSHRSTR:
                case LUA_TLNGSTR:
                    f->k_str[i] = LoadString(S);
#if LUACLIB_DEBUG
                    fprintf(stderr, "[luac]   k[%d]=str(len=%zu) '%s'\\n", i,
                            f->k_str[i] ? strlen(f->k_str[i]) : 0,
                            f->k_str[i] ? f->k_str[i] : "(null)");
#endif
                    break;''',
    '''                case LUA_TSHRSTR:
                case LUA_TLNGSTR: {
                    size_t slen = 0;
                    f->k_str[i] = LoadString(S, &slen);
                    f->k_str_len[i] = (int)slen;
#if LUACLIB_DEBUG
                    fprintf(stderr, "[luac]   k[%d]=str(len=%zu)\\n", i, slen);
#endif
                    break; }'''
))

# 11. DumpConstants: pass k_str_len[i]
replacements.append((
    '''            case LUA_TSHRSTR:
            case LUA_TLNGSTR: {
                const char *s = f->k_str[i];
                DumpString(D, s);
                break;
            }''',
    '''            case LUA_TSHRSTR:
            case LUA_TLNGSTR: {
                const char *s = f->k_str[i];
                DumpString(D, s, f->k_str_len ? (size_t)f->k_str_len[i] : (s ? strlen(s) : 0));
                break;
            }'''
))

# 12. LoadFunction: source with length
replacements.append((
    '''    f->source = LoadString(S);''',
    '''    { size_t slen = 0; f->source = LoadString(S, &slen); f->source_len = (int)slen; }'''
))

# 13. LoadFunction: locvar_name with length - allocate len array
replacements.append((
    '''        f->locvar_name = luac_alloc(sizeof(char *) * f->sizelocvars);
        f->locvar_startpc = luac_alloc(sizeof(int) * f->sizelocvars);
        f->locvar_endpc = luac_alloc(sizeof(int) * f->sizelocvars);
        for (int i = 0; i < f->sizelocvars; i++) {
            f->locvar_name[i] = LoadString(S);''',
    '''        f->locvar_name = luac_alloc(sizeof(char *) * f->sizelocvars);
        f->locvar_name_len = luac_alloc(sizeof(int) * f->sizelocvars);
        f->locvar_startpc = luac_alloc(sizeof(int) * f->sizelocvars);
        f->locvar_endpc = luac_alloc(sizeof(int) * f->sizelocvars);
        for (int i = 0; i < f->sizelocvars; i++) {
            size_t vlen = 0;
            f->locvar_name[i] = LoadString(S, &vlen);
            f->locvar_name_len[i] = (int)vlen;'''
))

# 14. LoadFunction: upval_name with length
replacements.append((
    '''        if (f->upval_name && i < f->sizeupvalues) {
            free(f->upval_name[i]);
            f->upval_name[i] = LoadString(S);
        } else {
            LoadString(S);  /* skip */
        }''',
    '''        if (f->upval_name && i < f->sizeupvalues) {
            free(f->upval_name[i]);
            size_t ulen = 0;
            f->upval_name[i] = LoadString(S, &ulen);
            if (!f->upval_name_len) f->upval_name_len = luac_alloc(sizeof(int) * f->sizeupvalues);
            f->upval_name_len[i] = (int)ulen;
        } else {
            size_t dummy; LoadString(S, &dummy);  /* skip */
        }'''
))

# 15. DumpFunction: source with length
replacements.append((
    '''    DumpString(D, f->source);''',
    '''    DumpString(D, f->source, f->source_len ? (size_t)f->source_len : (f->source ? strlen(f->source) : 0));'''
))

# 16. DumpFunction: locvar_name with length
replacements.append((
    '''        DumpString(D, f->locvar_name[i]);''',
    '''        DumpString(D, f->locvar_name[i], f->locvar_name_len ? (size_t)f->locvar_name_len[i] : (f->locvar_name[i] ? strlen(f->locvar_name[i]) : 0));'''
))

# 17. DumpFunction: upval_name with length
replacements.append((
    '''        DumpString(D, f->upval_name[i]);''',
    '''        DumpString(D, f->upval_name[i], f->upval_name_len ? (size_t)f->upval_name_len[i] : (f->upval_name[i] ? strlen(f->upval_name[i]) : 0));'''
))

# 18. push_constant: use lua_pushlstring
replacements.append((
    '''        case LUA_TSHRSTR:
        case LUA_TLNGSTR: lua_pushstring(L, f->k_str[idx] ? f->k_str[idx] : ""); break;''',
    '''        case LUA_TSHRSTR:
        case LUA_TLNGSTR:
            if (f->k_str[idx]) lua_pushlstring(L, f->k_str[idx], f->k_str_len ? (size_t)f->k_str_len[idx] : strlen(f->k_str[idx]));
            else lua_pushstring(L, "");
            break;'''
))

# 19. create_locvars_table: use lua_pushlstring
replacements.append((
    '''        if (f->locvar_name[i]) lua_pushstring(L, f->locvar_name[i]);
        else lua_pushnil(L);''',
    '''        if (f->locvar_name[i]) lua_pushlstring(L, f->locvar_name[i], f->locvar_name_len ? (size_t)f->locvar_name_len[i] : strlen(f->locvar_name[i]));
        else lua_pushnil(L);'''
))

# 20. sync_k_from_table: free k_str_len
replacements.append((
    '''    if (f->k_str) {
        for (int i = 0; i < f->sizek; i++) free(f->k_str[i]);
        free(f->k_str);
    }
    free(f->k_tag); free(f->k_num); free(f->k_bool);
    f->sizek = n;
    f->k_tag = NULL; f->k_str = NULL; f->k_num = NULL; f->k_bool = NULL;
    if (n > 0) {
        f->k_tag = luac_alloc(sizeof(int) * n);
        f->k_str = luac_alloc(sizeof(char *) * n);
        f->k_num = luac_alloc(sizeof(double) * n);
        f->k_bool = luac_alloc(sizeof(int) * n);''',
    '''    if (f->k_str) {
        for (int i = 0; i < f->sizek; i++) free(f->k_str[i]);
        free(f->k_str);
    }
    free(f->k_str_len);
    free(f->k_tag); free(f->k_num); free(f->k_bool);
    f->sizek = n;
    f->k_tag = NULL; f->k_str = NULL; f->k_str_len = NULL; f->k_num = NULL; f->k_bool = NULL;
    if (n > 0) {
        f->k_tag = luac_alloc(sizeof(int) * n);
        f->k_str = luac_alloc(sizeof(char *) * n);
        f->k_str_len = luac_alloc(sizeof(int) * n);
        f->k_num = luac_alloc(sizeof(double) * n);
        f->k_bool = luac_alloc(sizeof(int) * n);'''
))

# 21. sync_k_from_table: init k_str_len[i]
replacements.append((
    '''            f->k_str[i] = NULL;
            f->k_num[i] = 0;
            f->k_bool[i] = 0;''',
    '''            f->k_str[i] = NULL;
            f->k_str_len[i] = 0;
            f->k_num[i] = 0;
            f->k_bool[i] = 0;'''
))

# 22. sync_k_from_table: string case - use lua_tolstring and store length
replacements.append((
    '''            } else if (t == LUA_TSTRING) {
                const char *s = lua_tostring(L, -1);
                f->k_tag[i] = (strlen(s) <= 40) ? LUA_TSHRSTR : LUA_TLNGSTR;
                f->k_str[i] = luac_strdup(s);''',
    '''            } else if (t == LUA_TSTRING) {
                size_t slen = 0;
                const char *s = lua_tolstring(L, -1, &slen);
                f->k_tag[i] = (slen <= 40) ? LUA_TSHRSTR : LUA_TLNGSTR;
                f->k_str[i] = luac_strndup(s, slen);
                f->k_str_len[i] = (int)slen;'''
))

# 23. sync_locvars_from_table: free and allocate locvar_name_len
replacements.append((
    '''    if (f->locvar_name) {
        for (int i = 0; i < f->sizelocvars; i++) free(f->locvar_name[i]);
        free(f->locvar_name);
    }
    free(f->locvar_startpc); free(f->locvar_endpc);
    f->sizelocvars = n;
    f->locvar_name = NULL; f->locvar_startpc = NULL; f->locvar_endpc = NULL;
    if (n > 0) {
        f->locvar_name = luac_alloc(sizeof(char *) * n);
        f->locvar_startpc = luac_alloc(sizeof(int) * n);
        f->locvar_endpc = luac_alloc(sizeof(int) * n);''',
    '''    if (f->locvar_name) {
        for (int i = 0; i < f->sizelocvars; i++) free(f->locvar_name[i]);
        free(f->locvar_name);
    }
    free(f->locvar_name_len);
    free(f->locvar_startpc); free(f->locvar_endpc);
    f->sizelocvars = n;
    f->locvar_name = NULL; f->locvar_name_len = NULL; f->locvar_startpc = NULL; f->locvar_endpc = NULL;
    if (n > 0) {
        f->locvar_name = luac_alloc(sizeof(char *) * n);
        f->locvar_name_len = luac_alloc(sizeof(int) * n);
        f->locvar_startpc = luac_alloc(sizeof(int) * n);
        f->locvar_endpc = luac_alloc(sizeof(int) * n);'''
))

# 24. sync_locvars_from_table: varname with length
replacements.append((
    '''            if (lua_isnil(L, -1)) f->locvar_name[i] = NULL;
            else f->locvar_name[i] = luac_strdup(lua_tostring(L, -1));''',
    '''            if (lua_isnil(L, -1)) { f->locvar_name[i] = NULL; f->locvar_name_len[i] = 0; }
            else { size_t vlen = 0; const char *vs = lua_tolstring(L, -1, &vlen); f->locvar_name[i] = luac_strndup(vs, vlen); f->locvar_name_len[i] = (int)vlen; }'''
))

# 25. sync_upvalues_from_table: free and allocate upval_name_len
replacements.append((
    '''    if (f->upval_name) {
        for (int i = 0; i < f->sizeupvalues; i++) free(f->upval_name[i]);
        free(f->upval_name);
    }
    free(f->upval_instack); free(f->upval_idx);
    f->sizeupvalues = n;
    f->upval_name = NULL; f->upval_instack = NULL; f->upval_idx = NULL;
    if (n > 0) {
        f->upval_name = luac_alloc(sizeof(char *) * n);
        f->upval_instack = luac_alloc(sizeof(unsigned char) * n);
        f->upval_idx = luac_alloc(sizeof(unsigned char) * n);''',
    '''    if (f->upval_name) {
        for (int i = 0; i < f->sizeupvalues; i++) free(f->upval_name[i]);
        free(f->upval_name);
    }
    free(f->upval_name_len);
    free(f->upval_instack); free(f->upval_idx);
    f->sizeupvalues = n;
    f->upval_name = NULL; f->upval_name_len = NULL; f->upval_instack = NULL; f->upval_idx = NULL;
    if (n > 0) {
        f->upval_name = luac_alloc(sizeof(char *) * n);
        f->upval_name_len = luac_alloc(sizeof(int) * n);
        f->upval_instack = luac_alloc(sizeof(unsigned char) * n);
        f->upval_idx = luac_alloc(sizeof(unsigned char) * n);'''
))

# 26. sync_upvalues_from_table: name with length
replacements.append((
    '''            if (lua_isnil(L, -1)) f->upval_name[i] = NULL;
            else f->upval_name[i] = luac_strdup(lua_tostring(L, -1));''',
    '''            if (lua_isnil(L, -1)) { f->upval_name[i] = NULL; f->upval_name_len[i] = 0; }
            else { size_t ulen = 0; const char *us = lua_tolstring(L, -1, &ulen); f->upval_name[i] = luac_strndup(us, ulen); f->upval_name_len[i] = (int)ulen; }'''
))

# 27. proto_gc: free length arrays
replacements.append((
    '''    if (f->k_str) {
        for (int i = 0; i < f->sizek; i++) free(f->k_str[i]);
        free(f->k_str);
    }
    free(f->k_num); free(f->k_bool);
    free(f->lineinfo);
    if (f->locvar_name) {
        for (int i = 0; i < f->sizelocvars; i++) free(f->locvar_name[i]);
        free(f->locvar_name);
    }
    free(f->locvar_startpc); free(f->locvar_endpc);
    if (f->upval_name) {
        for (int i = 0; i < f->sizeupvalues; i++) free(f->upval_name[i]);
        free(f->upval_name);
    }
    free(f->upval_instack); free(f->upval_idx);
    free(f->source);''',
    '''    if (f->k_str) {
        for (int i = 0; i < f->sizek; i++) free(f->k_str[i]);
        free(f->k_str);
    }
    free(f->k_str_len);
    free(f->k_num); free(f->k_bool);
    free(f->lineinfo);
    if (f->locvar_name) {
        for (int i = 0; i < f->sizelocvars; i++) free(f->locvar_name[i]);
        free(f->locvar_name);
    }
    free(f->locvar_name_len);
    free(f->locvar_startpc); free(f->locvar_endpc);
    if (f->upval_name) {
        for (int i = 0; i < f->sizeupvalues; i++) free(f->upval_name[i]);
        free(f->upval_name);
    }
    free(f->upval_name_len);
    free(f->upval_instack); free(f->upval_idx);
    free(f->source);'''
))

# 28. source setter: use luaL_checklstring and store length
replacements.append((
    '''    if (strcmp(key, "source") == 0) {
        free(f->source);
        if (lua_isnil(L, 3)) {
            f->source = NULL;
        } else {
            f->source = luac_strdup(luaL_checkstring(L, 3));
        }
        return 0;
    }''',
    '''    if (strcmp(key, "source") == 0) {
        free(f->source);
        if (lua_isnil(L, 3)) {
            f->source = NULL;
            f->source_len = 0;
        } else {
            size_t slen = 0;
            const char *s = luaL_checklstring(L, 3, &slen);
            f->source = luac_strndup(s, slen);
            f->source_len = (int)slen;
        }
        return 0;
    }'''
))

# 29. clone: reset length pointers
replacements.append((
    '''    f->k_tag = NULL; f->k_str = NULL; f->k_num = NULL; f->k_bool = NULL;
    f->p = NULL;
    f->lineinfo = NULL;
    f->locvar_name = NULL; f->locvar_startpc = NULL; f->locvar_endpc = NULL;
    f->upval_name = NULL; f->upval_instack = NULL; f->upval_idx = NULL;
    f->source = NULL;''',
    '''    f->k_tag = NULL; f->k_str = NULL; f->k_str_len = NULL; f->k_num = NULL; f->k_bool = NULL;
    f->p = NULL;
    f->lineinfo = NULL;
    f->locvar_name = NULL; f->locvar_name_len = NULL; f->locvar_startpc = NULL; f->locvar_endpc = NULL;
    f->upval_name = NULL; f->upval_name_len = NULL; f->upval_instack = NULL; f->upval_idx = NULL;
    f->source = NULL; f->source_len = 0;'''
))

# Apply all replacements
failed = []
for i, (old, new) in enumerate(replacements):
    if old in src:
        src = src.replace(old, new, 1)
    else:
        failed.append(i)

if failed:
    print(f"FAILED replacements: {failed}")
    for i in failed:
        print(f"  --- replacement {i} old text ---")
        print(replacements[i][0][:200])
    sys.exit(1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print(f"All {len(replacements)} replacements applied successfully.")
