local luac = require("luac")
local anti_td = require("anti_td")

-- 编译 hello.lua
local func, err = loadfile("E:/LuaRes/luasafe/hello.lua")
if not func then
    print("compile error: " .. tostring(err))
    os.exit(1)
end

local bc = string.dec(string.dump(func))
print("Original size: " .. #bc)

-- undump
local p = luac.undump(bc, false)
print("Original main: numparams=" .. p.numparams .. " sizeupvalues=" .. p.sizeupvalues .. " lineinfo=" .. #p.lineinfo)

-- 只开启 anti_td 防护（所有选项都开启）
anti_td.protect(p, {
    poison_header = true,
    strip_lineinfo = true,
    junk_source = true,
    junk_upvalues = true,
    junk_constants = false,
})

print("Protected main: numparams=" .. p.numparams .. " sizeupvalues=" .. p.sizeupvalues .. " lineinfo=" .. #p.lineinfo)

-- dump
local out = luac.dump(p)
print("Protected size: " .. #out)

-- 验证可以正常加载和执行
local ok, f2 = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    print("Execute:")
    f2()
else
    print("  Error: " .. tostring(f2))
end

-- 写入文件
local fout = io.open("E:/LuaRes/luasafe/hello_protected.lua", "wb")
fout:write(out)
fout:close()
print("Written to E:/LuaRes/luasafe/hello_protected.lua")
