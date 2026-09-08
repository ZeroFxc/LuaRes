p = r'E:\LuaRes\luasafe\lvm.c'
s = open(p, encoding='utf-8').read()

# 1. Add windows.h include (guarded by LUA_VM_DEBUG)
old_inc = '#include "lvm.h"'
new_inc = '''#include "lvm.h"
#if LUA_VM_DEBUG
#include <windows.h>
#endif'''
s = s.replace(old_inc, new_inc, 1)

# 2. Add HeapValidate + generic PC trace inside the existing LUA_VM_DEBUG block
# Find the end of the ring buffer update (after _vm_last_idx line) and add before the "if (_vm_insn_count % 2000000" check
old_trace = '''        _vm_last_idx = (_vm_last_idx + 1) % 32;
        if (_vm_insn_count % 2000000 == 0) {'''
new_trace = '''        _vm_last_idx = (_vm_last_idx + 1) % 32;
        /* heap integrity check */
        if (!HeapValidate(GetProcessHeap(), 0, NULL)) {
            fprintf(stderr, "[HEAP-CORRUPT] insn=%lld pc=%d op=%d (%08x) sizecode=%d sizek=%d maxstack=%d\\n",
                _vm_insn_count, _pc, _op, i, cl->p->sizecode, cl->p->sizek, cl->p->maxstacksize);
            fflush(stderr);
        }
        /* per-instruction trace */
        fprintf(stderr, "[PC] %d %s (%08x) maxstack=%d sizek=%d\\n",
            _pc, _op < 47 ? _opnames[_op] : "?", i, cl->p->maxstacksize, cl->p->sizek);
        fflush(stderr);
        if (_vm_insn_count % 2000000 == 0) {'''
s = s.replace(old_trace, new_trace, 1)

# 3. Add fflush after LOADK fprintf
old_loadk = '''            (rb->tt_ == 4 || rb->tt_ == 20 || rb->tt_ == 68) ? getstr(tsvalue(rb)) : "(non-str)");
#endif
        setobj2s(L, ra, rb);'''
new_loadk = '''            (rb->tt_ == 4 || rb->tt_ == 20 || rb->tt_ == 68) ? getstr(tsvalue(rb)) : "(non-str)");
        fflush(stderr);
#endif
        setobj2s(L, ra, rb);'''
s = s.replace(old_loadk, new_loadk, 1)

# 4. Add BXOR debug output
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
print('debug code added with LUA_VM_DEBUG guard')
