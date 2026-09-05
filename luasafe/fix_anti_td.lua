-- fix_anti_td.lua: 修复被 anti-TD 混淆的 andlua Lua 5.3 字节码
-- andlua header 格式: 33 字节 (4 sig + 1 ver + 1 fmt + 6 LUAC_DATA + 5 sizes + 8 LUAC_INT + 8 LUAC_NUM)
-- 用法: lua_luac.exe fix_anti_td.lua <input.lua> <output.lua>

local luac = require("luac")

local function fix_proto(p, is_main)
    -- 修复函数头异常字段
    if is_main then
        p.numparams = 0
        p.is_vararg = 0
        p.maxstacksize = 2
        p.linedefined = 0
        p.lastlinedefined = 0
    else
        if p.numparams > 100 then p.numparams = 0 end
        if p.is_vararg > 2 then p.is_vararg = 0 end
        if p.maxstacksize > 100 then p.maxstacksize = 2 end
        if p.linedefined > 1000000 then p.linedefined = 0 end
        if p.lastlinedefined < 0 then p.lastlinedefined = 0 end
    end

    -- 修复 sizeupvalues 异常
    if p.sizeupvalues > 100 then
        p.sizeupvalues = 0
        p.upval_instack = {}
        p.upval_idx = {}
        p.upval_name = {}
    end

    -- 修复 lineinfo：如果数量与 code 不匹配，重建为全 0
    if #p.lineinfo ~= #p.code then
        local new_lineinfo = {}
        for i = 1, #p.code do new_lineinfo[i] = 0 end
        p.lineinfo = new_lineinfo
    end

    -- 修复 locvars：异常数量清零
    if #p.locvars > 1000 then
        p.locvars = {}
    end

    -- 递归修复子函数
    for i = 1, #p.p do
        fix_proto(p.p[i], false)
    end
end

local function fix_header(data)
    -- andlua 33 字节 header: 只修复 LUAC_NUM (偏移 25-32, 0-based)
    -- 标准 LUAC_NUM = 3.14159265358979323846 的小端表示
    local luac_num = string.char(0x18, 0x2D, 0x44, 0x54, 0xFB, 0x21, 0x09, 0x40)
    -- 偏移 25-32 (1-based 是 26-33)
    return data:sub(1, 25) .. luac_num .. data:sub(34)
end

-- 主程序
local input = arg[1]
local output = arg[2]

if not input or not output then
    print("Usage: lua_luac.exe fix_anti_td.lua <input.lua> <output.lua>")
    os.exit(1)
end

local f = io.open(input, "rb")
if not f then
    print("Error: cannot open " .. input)
    os.exit(1)
end
local data = f:read("*a")
f:close()

print("Input size: " .. #data .. " bytes")

-- 修复 header (LUAC_NUM)
data = fix_header(data)
print("Header LUAC_NUM fixed")

-- undump
local p = luac.undump(data, false)
print("Undump OK")

-- 统计
local function count(p)
    local c = 1
    for i = 1, #p.p do c = c + count(p.p[i]) end
    return c
end
print("Total functions: " .. count(p))

-- 修复所有函数
fix_proto(p, true)
print("All protos fixed")

-- dump
local out = luac.dump(p)
print("Output size: " .. #out .. " bytes")

-- 验证
local p2 = luac.undump(out, false)
local function count_code(p)
    local c = #p.code
    for i = 1, #p.p do c = c + count_code(p.p[i]) end
    return c
end
print("Re-undump instructions: " .. count_code(p2))

-- 测试 load
local ok, err = pcall(load, out)
print("Load test: " .. tostring(ok))
if not ok then print("  Error: " .. tostring(err)) end

-- 写入
local fout = io.open(output, "wb")
fout:write(out)
fout:close()
print("Written to " .. output)
