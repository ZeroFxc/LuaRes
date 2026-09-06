with open(r'E:\LuaRes\luasafe\lvm.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """#if LUA_VM_DEBUG
        fprintf(stderr, "[VM] SETTABLE A=%d B=%d C=%d ra_tt=%d rb_tt=%d rc_tt=%d\\n", GETARG_A(i), GETARG_B(i), GETARG_C(i), ra->tt_, rb->tt_, rc->tt_);
#endif"""

new = """#if LUA_VM_DEBUG
        fprintf(stderr, "[VM] SETTABLE A=%d B=%d C=%d ra_tt=%d rb_tt=%d rb_ival=%lld rc_tt=%d rc_str=%s\\n",
            GETARG_A(i), GETARG_B(i), GETARG_C(i),
            ra->tt_, rb->tt_,
            (rb->tt_ == 19) ? (long long)rb->value_.i : 0,
            rc->tt_,
            (rc->tt_ == 4 || rc->tt_ == 20 || rc->tt_ == 68) ? getstr(tsvalue(rc)) : "(non-str)");
#endif"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luasafe\lvm.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
