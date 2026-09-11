path = r'E:\LuaRes\luaclib\luac.h'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'luac_new_proto' in line or 'luac_check_proto' in line or 'luac_dump_data' in line:
        continue
    new_lines.append(line)

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('done')
