path = r'E:\LuaRes\luaclib\obf_util.c'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the cleanup section - just leave sub_ud on top, don't settop
old = '''    fprintf(stderr, "DBG: cleanup top=%d current_top=%d\\n", top, lua_gettop(L)); fflush(stderr);
    /* cleanup: leave only sub_ud on stack */
    lua_replace(L, top + 1);
    fprintf(stderr, "DBG: after replace top=%d\\n", lua_gettop(L)); fflush(stderr);
    lua_settop(L, top + 1);
    fprintf(stderr, "DBG: after settop top=%d\\n", lua_gettop(L)); fflush(stderr);
    fprintf(stderr, "DBG: sub_ud->maxstacksize=%d\\n", sub_ud->maxstacksize); fflush(stderr);
    fprintf(stderr, "DBG: sub_ud->sizecode=%d\\n", sub_ud->sizecode); fflush(stderr);

    return sub_ud;'''

new = '''    /* leave sub_ud on top of stack; caller is responsible for cleanup */
    fprintf(stderr, "DBG: returning sub_ud=%p top=%d\\n", (void*)sub_ud, lua_gettop(L)); fflush(stderr);
    return sub_ud;'''

if old in content:
    content = content.replace(old, new, 1)
    print('replaced cleanup')
else:
    print('pattern NOT FOUND')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
