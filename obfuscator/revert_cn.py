with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 替换 read_file 为简单 io.open
old_read = """local function read_file(path)
    -- 先尝试 io.open（ASCII 路径）
    local f = io.open(path, 'rb')
    if f then
        local data = f:read('*a')
        f:close()
        return data
    end
    -- 中文路径：用 type 命令读取
    local p = io.popen('type "' .. path .. '" 2>nul', 'rb')
    if p then
        local data = p:read('*a')
        p:close()
        if data and #data > 0 then return data end
    end
    return nil
end"""

new_read = """local function read_file(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local data = f:read('*a')
    f:close()
    return data
end"""

content = content.replace(old_read, new_read, 1)

# 2. 替换输出写入为简单 io.open
old_write = """    local out_bc = luac.dump(proto)
    -- 写入输出（支持中文路径：先写临时文件再复制）
    local tmp_out = os.getenv('TEMP') and (os.getenv('TEMP') .. '/luac_menu_tmp.luac') or 'luac_menu_tmp.luac'
    local fout = io.open(tmp_out, 'wb')
    if not fout then print('ERROR: 无法写入临时文件'); return end
    fout:write(out_bc)
    fout:close()
    if tmp_out ~= output then
        -- 检测输出路径是否含非ASCII（中文等），Windows cmd 无法正确处理
        local has_non_ascii = false
        for ci = 1, #output do
            if output:byte(ci) > 127 then has_non_ascii = true; break end
        end
        if has_non_ascii then
            local fallback = 'luac_output.luac'
            print('DEBUG: has_non_ascii=true')
            os.execute('copy /Y /b "' .. tmp_out .. '" "' .. fallback .. '" >nul 2>nul')
            print('注意: 输出路径含中文，已保存到当前目录: ' .. fallback)
        else
            os.execute('copy /Y /b "' .. tmp_out .. '" "' .. output .. '" >nul 2>nul')
        end
    end"""

new_write = """    local out_bc = luac.dump(proto)
    local fout = io.open(output, 'wb')
    if not fout then print('ERROR: 无法写入 ' .. output); return end
    fout:write(out_bc)
    fout:close()"""

content = content.replace(old_write, new_write, 1)

with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
