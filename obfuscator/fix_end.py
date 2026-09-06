with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    content = f.read()

old = """        else
            os.execute('copy /Y /b "' .. tmp_out .. '" "' .. output .. '" >nul 2>nul')
        end

    print('---')"""

new = """        else
            os.execute('copy /Y /b "' .. tmp_out .. '" "' .. output .. '" >nul 2>nul')
        end
    end

    print('---')"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
