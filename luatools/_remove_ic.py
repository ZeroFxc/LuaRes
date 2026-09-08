import re

# 1. Remove from wasm_entry.c MODULE_LIST
p = r'E:\LuaRes\luaclib\wasm_entry.c'
s = open(p, encoding='utf-8').read()
s = s.replace('    "loop_restructure_c,"\n    "integrity_check_c";', '    "loop_restructure_c";')
open(p, 'w', encoding='utf-8').write(s)
print('wasm_entry.c done')

# 2. Remove from web/app.js
p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()
# Remove from module group
s = s.replace("    { id: 'integrity_check_c', label: '完整性校验', desc: '运行时FNV-1a哈希校验字节码，仅用标准库(debug/string)，篡改则死循环' },\n", "")
# Remove from EXEC_ORDER
s = s.replace("'live_range_split_c','op48_junk_c','integrity_check_c','vm_embed_c'", "'live_range_split_c','op48_junk_c','vm_embed_c'")
open(p, 'w', encoding='utf-8').write(s)
print('app.js done')

# 3. Remove from obf_register.c
p = r'E:\LuaRes\luaclib\obf_register.c'
s = open(p, encoding='utf-8').read()
s = s.replace('int integrity_check_process(lua_State *L);\n', '')
s = s.replace('    {"integrity_check_c", integrity_check_process},\n', '')
open(p, 'w', encoding='utf-8').write(s)
print('obf_register.c done')

print('all done')
