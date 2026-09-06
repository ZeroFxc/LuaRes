with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 替换第 312-316 行（0-indexed 311-315）
new_lines = []
skip = 0
for i, line in enumerate(lines):
    if skip > 0:
        skip -= 1
        continue
    if i == 311:  # if tmp_out ~= output then
        new_lines.append("    if tmp_out ~= output then\n")
        new_lines.append("        -- 检测输出路径是否含非ASCII（中文等），Windows cmd 无法正确处理\n")
        new_lines.append("        local has_non_ascii = false\n")
        new_lines.append("        for ci = 1, #output do\n")
        new_lines.append("            if output:byte(ci) > 127 then has_non_ascii = true; break end\n")
        new_lines.append("        end\n")
        new_lines.append("        if has_non_ascii then\n")
        new_lines.append("            local fallback = 'luac_output.luac'\n")
        new_lines.append("            os.execute('copy /Y /b \"' .. tmp_out .. '\" \"' .. fallback .. '\" >nul 2>nul')\n")
        new_lines.append("            print('注意: 输出路径含中文，已保存到当前目录: ' .. fallback)\n")
        new_lines.append("        else\n")
        new_lines.append("            os.execute('copy /Y /b \"' .. tmp_out .. '\" \"' .. output .. '\" >nul 2>nul')\n")
        new_lines.append("        end\n")
        skip = 4  # 跳过原来的 313-316 行（4行）
        continue
    new_lines.append(line)

with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('OK')
