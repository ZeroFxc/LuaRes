with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    content = f.read()

old = """    -- 读取输入
    local fin = io.open(input, 'rb')
    if not fin then print('ERROR: 无法打开 ' .. input); return end
    local data = fin:read('*a')
    fin:close()"""

new = """    -- 读取输入
    local data = read_file(input)
    if not data then print('ERROR: 无法打开 ' .. input); return end"""

if old in content:
    content = content.replace(old, new, 1)
    with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
