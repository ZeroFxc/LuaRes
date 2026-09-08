p = r'E:\LuaRes\luasafe\lundump.c'
s = open(p, encoding='utf-8').read()
old = 'static void LoadConstants (LoadState *S, Proto *f) {\n  int i;\n  int n = LoadInt(S);'
new = 'static void LoadConstants (LoadState *S, Proto *f) {\n  int i;\n  int n = LoadInt(S);\n  fprintf(stderr, "[LUNDUMP] LoadConstants start n=%d\\n", n); fflush(stderr);'
if old in s:
    s = s.replace(old, new)
    # add end marker before closing brace
    old2 = '    default:\n      lua_assert(0);\n    }\n  }\n}'
    new2 = '    default:\n      lua_assert(0);\n    }\n  }\n  fprintf(stderr, "[LUNDUMP] LoadConstants done\\n"); fflush(stderr);\n}'
    if old2 in s:
        s = s.replace(old2, new2)
        open(p, 'w', encoding='utf-8').write(s)
        print('both added')
    else:
        print('end marker NOT FOUND')
        open(p, 'w', encoding='utf-8').write(s)
else:
    print('start NOT FOUND')
