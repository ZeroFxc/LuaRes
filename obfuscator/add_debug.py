with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    content = f.read()

old = """        if has_non_ascii then
            local fallback = 'luac_output.luac'
            os.execute('copy /Y /b "' .. tmp_out .. '" "' .. fallback .. '" >nul 2>nul')
            print('注意: 输出路径含中文，已保存到当前目录: ' .. fallback)"""

new = """        if has_non_ascii then
            local fallback = 'luac_output.luac'
            print('DEBUG: has_non_ascii=true')
            os.execute('copy /Y /b "' .. tmp_out .. '" "' .. fallback .. '" >nul 2>nul')
            print('注意: 输出路径含中文，已保存到当前目录: ' .. fallback)"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
