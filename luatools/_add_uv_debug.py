p = r'E:\LuaRes\luaclib\vm_asm\vm_asm_runtime.c'
s = open(p, encoding='utf-8').read()

# Add UV debug macro after includes
old_inc = '#include "vm_asm.h"\n#include <stdlib.h>\n#include <string.h>\n'
new_inc = '''#include "vm_asm.h"
#include <stdlib.h>
#include <string.h>

/* UV debug macro: compile with -DVM_ASM_UV_DEBUG=1 to enable */
#ifndef VM_ASM_UV_DEBUG
#define VM_ASM_UV_DEBUG 0
#endif
'''
if old_inc in s:
    s = s.replace(old_inc, new_inc, 1)
    print("Added UV debug macro")
else:
    print("ERROR: include block not found")

# Add debug logging to getuv
old_getuv = '''        "  local function getuv(i)\\n"
        "    local u = %s[i]\\n"
        "    if not u then return nil end\\n"
        "    if u.cell then\\n"
        "      if u.cell.reg then return u.cell.reg[u.cell.idx] end\\n"
        "      return u.cell.val\\n"
        "    end\\n"
        "    return u.val\\n"
        "  end\\n", UV);'''

new_getuv = '''        "  local function getuv(i)\\n"
        "    local u = %s[i]\\n"
        "    if not u then return nil end\\n"
        "    if u.cell then\\n"
        "      if u.cell.reg then local v = u.cell.reg[u.cell.idx]; if _uvdbg and i>0 then io.stderr:write('GETUV i='..i..' reg='..tostring(v)..'\\\\n') end return v end\\n"
        "      if _uvdbg and i>0 then io.stderr:write('GETUV i='..i..' closed val='..tostring(u.cell.val)..'\\\\n') end\\n"
        "      return u.cell.val\\n"
        "    end\\n"
        "    if _uvdbg and i>0 then io.stderr:write('GETUV i='..i..' plain val='..tostring(u.val)..'\\\\n') end\\n"
        "    return u.val\\n"
        "  end\\n", UV);'''

if old_getuv in s:
    s = s.replace(old_getuv, new_getuv, 1)
    print("Added debug to getuv")
else:
    print("ERROR: getuv block not found")
    # find it
    idx = s.find('local function getuv')
    print(repr(s[idx-20:idx+200]))

open(p, 'w', encoding='utf-8').write(s)
print("Done")
