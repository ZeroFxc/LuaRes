p = r'E:\LuaRes\luasafe\lvm.c'
s = open(p, encoding='utf-8').read()

# Find BXOR case and add debug
old_bxor = '''      vmcase(OP_BXOR) {
        lua_Integer b = intival(rb);
        lua_Integer c = intival(rc);
        setivalue(ra, b ^ c);
        vmbreak;
      }'''
new_bxor = '''      vmcase(OP_BXOR) {
        lua_Integer b = intival(rb);
        lua_Integer c = intival(rc);
#if LUA_VM_DEBUG
        fprintf(stderr, "[VM] BXOR A=%d B=%d C=%d b=%lld c=%lld\\n", GETARG_A(i), GETARG_B(i), GETARG_C(i), (long long)b, (long long)c);
        fflush(stderr);
#endif
        setivalue(ra, b ^ c);
        vmbreak;
      }'''
s = s.replace(old_bxor, new_bxor, 1)

# Find SETTABLE case and add debug
old_settable = '''      vmcase(OP_SETTABLE) {
        TValue *rb = RB(i);
        TValue *rc = RC(i);
        luaV_settable(L, ra, rb, rc);
        vmbreak;
      }'''
new_settable = '''      vmcase(OP_SETTABLE) {
        TValue *rb = RB(i);
        TValue *rc = RC(i);
#if LUA_VM_DEBUG
        fprintf(stderr, "[VM] SETTABLE A=%d B=%d C=%d ra_tt=%d rb_tt=%d rc_tt=%d\\n", GETARG_A(i), GETARG_B(i), GETARG_C(i), ra->tt_, rb->tt_, rc->tt_);
        fflush(stderr);
#endif
        luaV_settable(L, ra, rb, rc);
        vmbreak;
      }'''
s = s.replace(old_settable, new_settable, 1)

open(p, 'w', encoding='utf-8').write(s)
print('debug added for BXOR and SETTABLE')
