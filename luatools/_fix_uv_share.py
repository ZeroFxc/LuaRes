p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_runtime.c'
s = open(p, encoding='utf-8').read()

old = '        "      else\n"        "        uv[i] = {val = getuv(d.idx)}\n"        "      end\n"'
new = '        "      else\n"        "        uv[i] = %s[d.idx] or {val = nil}\n"        "      end\n"'

if old in s:
    s = s.replace(old, new, 1)
    print("Replaced uv[i] copy with shared reference")
else:
    print("ERROR: old pattern not found")
    idx = s.find('uv[i] = {val = getuv')
    print(repr(s[idx-60:idx+80]))

# Add UV to format args for makeclosure
old_fmt = '    return wrap(factory(uv))\n"  "  end\n", PROTO, PROTO, R);'
new_fmt = '    return wrap(factory(uv))\n"  "  end\n", PROTO, PROTO, R, UV);'

if old_fmt in s:
    s = s.replace(old_fmt, new_fmt, 1)
    print("Added UV to format args")
else:
    print("ERROR: format pattern not found")
    idx = s.find('PROTO, PROTO, R')
    print(repr(s[idx-30:idx+40]))

open(p, 'w', encoding='utf-8').write(s)
print("Done")
