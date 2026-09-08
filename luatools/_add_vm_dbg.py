p = r'E:\LuaRes\luasafe\lvm.c'
s = open(p, encoding='utf-8').read()
old = '#if LUA_VM_DEBUG\n        fprintf(stderr, "[VM] LOADK A=%d Bx=%d rb_tt=%d rb_ival=%lld rb_str=%s\\n",'
new = '#if LUA_VM_DEBUG\n        fprintf(stderr, "[VM] LOADK A=%d Bx=%d k=%p sizek=%d rb_tt=%d rb_ival=%lld rb_str=%s\\n",\n            GETARG_A(i), GETARG_Bx(i), (void*)k, cl->p->sizek,'
if old in s:
    s = s.replace(old, new)
    # fix the argument list (remove duplicate A/Bx)
    old2 = '            GETARG_A(i), GETARG_Bx(i), rb->tt_,'
    new2 = '            rb->tt_,'
    if old2 in s:
        s = s.replace(old2, new2)
    open(p, 'w', encoding='utf-8').write(s)
    print('LOADK debug enhanced')
else:
    print('NOT FOUND')
