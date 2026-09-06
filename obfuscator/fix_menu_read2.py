with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 替换第 278-281 行（0-indexed: 277-280）
new_lines = []
skip = 0
for i, line in enumerate(lines):
    if skip > 0:
        skip -= 1
        continue
    if i == 277:  # local fin = io.open(input, 'rb')
        new_lines.append("    local data = read_file(input)\n")
        new_lines.append("    if not data then print('ERROR: 无法打开 ' .. input); return end\n")
        skip = 3  # 跳过原来的 4 行（278-281），但已经写了第278行，所以跳过3行
        continue
    new_lines.append(line)

with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('OK')
