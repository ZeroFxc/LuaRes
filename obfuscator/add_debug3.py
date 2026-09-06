with open(r'E:\LuaRes\luasafe\lvm.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """      vmcase(OP_LOADK) {
        TValue *rb = KBx(i);
        setobj2s(L, ra, rb);
        vmbreak;
      }"""

new = """      vmcase(OP_LOADK) {
        TValue *rb = KBx(i);
#if LUA_VM_DEBUG
        fprintf(stderr, "[VM] LOADK A=%d Bx=%d rb_tt=%d rb_ival=%lld rb_str=%s\\n",
            GETARG_A(i), (int)((i >> 14) & 0x3FFFF), rb->tt_,
            (rb->tt_ == 19) ? (long long)rb->value_.i : 0,
            (rb->tt_ == 4 || rb->tt_ == 20 || rb->tt_ == 68) ? getstr(tsvalue(rb)) : "(non-str)");
#endif
        setobj2s(L, ra, rb);
        vmbreak;
      }"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luasafe\lvm.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
