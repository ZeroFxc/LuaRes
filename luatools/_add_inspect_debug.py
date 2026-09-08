p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()

old = '''    lua_pop(L,1); /* code table */

    /* subprotos (recursive, depth-limited) */'''

new = '''    lua_pop(L,1); /* code table */

    /* debug info: locvars */
    lua_getfield(L, abs_p, "sizelocvars"); int sizelocvars = (int)lua_tointeger(L,-1); lua_pop(L,1);
    sb_putf(sb,",\\"sizelocvars\\":%d,\\"locvars\\":[", sizelocvars);
    lua_getfield(L, abs_p, "locvars");
    if(lua_istable(L,-1)){
        for(int i=1;i<=sizelocvars;i++){
            if(i>1) sb_putc(sb,',');
            lua_rawgeti(L,-1,i);
            if(lua_istable(L,-1)){
                lua_getfield(L,-1,"varname"); const char *vn = lua_tostring(L,-1); lua_pop(L,1);
                lua_getfield(L,-1,"startpc"); int spc = (int)lua_tointeger(L,-1); lua_pop(L,1);
                lua_getfield(L,-1,"endpc"); int epc = (int)lua_tointeger(L,-1); lua_pop(L,1);
                sb_puts(sb,"{\\"idx\\":"); sb_putf(sb,"%d",i-1); sb_puts(sb,",\\"varname\\":");
                sb_json_str(sb, vn ? vn : "null", vn ? strlen(vn) : 4);
                sb_putf(sb,",\\"startpc\\":%d,\\"endpc\\":%d}", spc, epc);
            } else {
                sb_puts(sb,"null");
            }
            lua_pop(L,1);
        }
    }
    lua_pop(L,1); /* locvars table */
    sb_putc(sb,']');

    /* debug info: lineinfo (first N) */
    lua_getfield(L, abs_p, "sizelineinfo"); int sizelineinfo = (int)lua_tointeger(L,-1); lua_pop(L,1);
    int show_li = sizelineinfo < 100 ? sizelineinfo : 100;
    sb_putf(sb,",\\"sizelineinfo\\":%d,\\"lineinfo_show\\":%d,\\"lineinfo\\":[", sizelineinfo, show_li);
    lua_getfield(L, abs_p, "lineinfo");
    if(lua_istable(L,-1)){
        for(int i=1;i<=show_li;i++){
            if(i>1) sb_putc(sb,',');
            lua_rawgeti(L,-1,i);
            sb_putf(sb,"%d",(int)lua_tointeger(L,-1));
            lua_pop(L,1);
        }
    }
    lua_pop(L,1); /* lineinfo table */
    if(sizelineinfo > 100) sb_puts(sb,"],\\"lineinfo_truncated\\":true");
    else sb_putc(sb,']');

    /* upvalues */
    lua_getfield(L, abs_p, "sizeupvalues"); int sizeupvalues = (int)lua_tointeger(L,-1); lua_pop(L,1);
    sb_putf(sb,",\\"sizeupvalues\\":%d,\\"upvalues\\":[", sizeupvalues);
    lua_getfield(L, abs_p, "upvalues");
    if(lua_istable(L,-1)){
        for(int i=1;i<=sizeupvalues;i++){
            if(i>1) sb_putc(sb,',');
            lua_rawgeti(L,-1,i);
            if(lua_istable(L,-1)){
                lua_getfield(L,-1,"name"); const char *un = lua_tostring(L,-1); lua_pop(L,1);
                lua_getfield(L,-1,"instack"); int uis = (int)lua_tointeger(L,-1); lua_pop(L,1);
                lua_getfield(L,-1,"idx"); int uidx = (int)lua_tointeger(L,-1); lua_pop(L,1);
                sb_puts(sb,"{\\"idx\\":"); sb_putf(sb,"%d",i-1); sb_puts(sb,",\\"name\\":");
                sb_json_str(sb, un ? un : "null", un ? strlen(un) : 4);
                sb_putf(sb,",\\"instack\\":%d,\\"idx\\":%d}", uis, uidx);
            } else {
                sb_puts(sb,"null");
            }
            lua_pop(L,1);
        }
    }
    lua_pop(L,1); /* upvalues table */
    sb_putc(sb,']');

    /* subprotos (recursive, depth-limited) */'''

if old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('replaced successfully')
else:
    print('old string not found!')
    # find the actual string
    idx = s.find('code table */')
    if idx >= 0:
        print('found at', idx)
        print(repr(s[idx:idx+100]))
