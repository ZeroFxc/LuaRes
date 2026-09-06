with open(r'E:\LuaRes\luasafe\lvm.c', 'r', encoding='utf-8') as f:
    content = f.read()

old = """      vmcase(OP_SETTABLE) {
        TValue *rb = RKB(i);
        TValue *rc = RKC(i);
        if(ttistable(ra)) {"""

new = """      vmcase(OP_SETTABLE) {
        TValue *rb = RKB(i);
        TValue *rc = RKC(i);
#if LUA_VM_DEBUG
        fprintf(stderr, "[VM] SETTABLE A=%d B=%d C=%d ra_tt=%d rb_tt=%d rc_tt=%d\\n", GETARG_A(i), GETARG_B(i), GETARG_C(i), ra->tt_, rb->tt_, rc->tt_);
#endif
        if(ttistable(ra)) {"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luasafe\lvm.c', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
