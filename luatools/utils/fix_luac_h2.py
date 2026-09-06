path = r'E:\LuaRes\luaclib\luac.h'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find and replace lines 109-115 (0-indexed 108-114)
new_lines = []
skip_until = -1
for i, line in enumerate(lines):
    if i == skip_until:
        skip_until = -1
    if 'luac_new_proto' in line:
        new_lines.append('luac_Proto *luac_new_proto(void);\n')
        new_lines.append('luac_Proto *luac_check_proto(lua_State *L, int idx);\n')
        new_lines.append('void luac_push_proto(lua_State *L, luac_Proto *p);\n')
        skip_until = i + 6  # skip through luac_dump_data line
        continue
    if skip_until > 0 and i < skip_until:
        continue
    new_lines.append(line)

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('done')
