with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    content = f.read()

old = """    -- 中文路径：用 type 命令读取
    local p = io.popen('type "' .. path .. '" 2>nul', 'rb')
    if p then
        local data = p:read('*a')
        p:close()
        if data and #data > 0 then return data end
    end"""

new = """    -- 中文路径：用 chcp 65001 + type 命令读取
    local p = io.popen('cmd /c "chcp 65001 >nul & type "' .. path .. '"" 2>nul', 'rb')
    if p then
        local data = p:read('*a')
        p:close()
        if data and #data > 0 then return data end
    end"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
