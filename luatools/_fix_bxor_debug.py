p = r'E:\LuaRes\luasafe\lvm.c'
s = open(p, encoding='utf-8').read()

# Correct BXOR case
old_bxor = '''      vmcase(OP_BXOR) {
        TValue *rb = RKB(i);
        TValue *rc = RKC(i);
        lua_Integer ib; lua_Integer ic;
        if (tointeger(rb, &ib) && tointeger(rc, &ic)) {
          setivalue(ra, intop(^, ib, ic));
        }
        else { Protect(luaT_trybinTM(L, rb, rc, ra, TM_BXOR)); }
        vmbreak;
      }'''
new_bxor = '''      vmcase(OP_BXOR) {
        TValue *rb = RKB(i);
        TValue *rc = RKC(i);
#if LUA_VM_DEBUG
        fprintf(stderr, "[VM] BXOR A=%d B=%d C=%d rb_tt=%d rc_tt=%d\\n", GETARG_A(i), GETARG_B(i), GETARG_C(i), rb->tt_, rc->tt_);
        fflush(stderr);
#endif
        lua_Integer ib; lua_Integer ic;
        if (tointeger(rb, &ib) && tointeger(rc, &ic)) {
          setivalue(ra, intop(^, ib, ic));
        }
        else { Protect(luaT_trybinTM(L, rb, rc, ra, TM_BXOR)); }
        vmbreak;
      }'''
s = s.replace(old_bxor, new_bxor, 1)

open(p, 'w', encoding='utf-8').write(s)
print('BXOR debug inserted correctly')
