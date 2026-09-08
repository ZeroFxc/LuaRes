p = r'E:\LuaRes\luasafe\lvm.c'
s = open(p, encoding='utf-8').read()

# Add windows.h include at the top
old_inc = '#include "lvm.h"'
new_inc = '''#include "lvm.h"
#include <windows.h>'''
s = s.replace(old_inc, new_inc, 1)

# Add HeapValidate after vmfetch()
old_fetch = '''    vmfetch();
#if LUA_VM_DEBUG'''
new_fetch = '''    vmfetch();
    {
        static long long _hv_count = 0;
        _hv_count++;
        if (!HeapValidate(GetProcessHeap(), 0, NULL)) {
            int _pc = (int)((ci->u.l.savedpc - 1) - cl->p->code);
            int _op = i & 0x3F;
            fprintf(stderr, "[HEAP-CORRUPT] insn=%lld pc=%d op=%d (%08x) sizecode=%d sizek=%d\\n",
                _hv_count, _pc, _op, i, cl->p->sizecode, cl->p->sizek);
            fflush(stderr);
        }
    }
#if LUA_VM_DEBUG'''
s = s.replace(old_fetch, new_fetch, 1)

open(p, 'w', encoding='utf-8').write(s)
print('HeapValidate added')
