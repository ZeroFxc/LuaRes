with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    content = f.read()

old = """    if tmp_out ~= output then
        -- 用 PowerShell 复制，支持中文路径
        local ps_cmd = 'powershell -NoProfile -Command "Copy-Item -LiteralPath \\'' .. tmp_out .. '\\' -Destination \\'' .. output .. '\\'"'
        os.execute(ps_cmd)
    end"""

new = """    if tmp_out ~= output then
        -- 检测输出路径是否含非ASCII（中文等），Windows cmd 无法正确处理
        local has_non_ascii = false
        for i = 1, #output do
            if output:byte(i) > 127 then has_non_ascii = true; break end
        end
        if has_non_ascii then
            -- 中文路径：输出到当前目录的固定文件名
            local fallback = 'luac_output.luac'
            os.execute('copy /Y /b "' .. tmp_out .. '" "' .. fallback .. '" >nul 2>nul')
            print('注意: 输出路径含中文，已保存到当前目录: ' .. fallback)
        else
            os.execute('copy /Y /b "' .. tmp_out .. '" "' .. output .. '" >nul 2>nul')
        end
    end"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
