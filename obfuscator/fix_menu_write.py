with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 找到输出写入部分（第 306-309 行，0-indexed 305-308）
new_lines = []
skip = 0
for i, line in enumerate(lines):
    if skip > 0:
        skip -= 1
        continue
    if i == 305:  # local fout = io.open(output, 'wb')
        new_lines.append("    -- 写入输出（支持中文路径：先写临时文件再复制）\n")
        new_lines.append("    local tmp_out = os.getenv('TEMP') and (os.getenv('TEMP') .. '/luac_menu_tmp.luac') or 'luac_menu_tmp.luac'\n")
        new_lines.append("    local fout = io.open(tmp_out, 'wb')\n")
        new_lines.append("    if not fout then print('ERROR: 无法写入临时文件'); return end\n")
        new_lines.append("    fout:write(out_bc)\n")
        new_lines.append("    fout:close()\n")
        new_lines.append("    if tmp_out ~= output then\n")
        new_lines.append("        os.execute('copy /Y \"' .. tmp_out .. '\" \"' .. output .. '\" >nul 2>nul')\n")
        new_lines.append("    end\n")
        skip = 3  # 跳过原来的 4 行中的后 3 行
        continue
    new_lines.append(line)

with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('OK')
