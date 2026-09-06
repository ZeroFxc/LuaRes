with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    content = f.read()

old = """    if tmp_out ~= output then
        os.execute('cmd /c "chcp 65001 >nul & copy /Y /b "' .. tmp_out .. '" "' .. output .. '" >nul 2>nul"')
    end"""

new = """    if tmp_out ~= output then
        -- 用 PowerShell 复制，支持中文路径
        local ps_cmd = 'powershell -NoProfile -Command "Copy-Item -LiteralPath \'' .. tmp_out .. '\' -Destination \'' .. output .. '\'"'
        os.execute(ps_cmd)
    end"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
