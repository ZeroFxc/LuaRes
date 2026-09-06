local luac = require("luac")
local protect = require("protect")

-- 编译 hello world
local func = load("print('hello world')")
local bc = string.dec(string.dump(func))
print("Original size: " .. #bc)

-- 只开 antidec + op48
local out, stats = protect.protect(bc, {
    no_strip = true,
    no_shuffle = true,
    no_mutate = true,
    no_flatten = true,
    no_opaque = true,
    no_obfuscate = true,
    no_antidec = false,
    no_op48 = false,
    op48_count = 100,
    op48_mode = "blocks",
})

print("Protected size: " .. #out)
print("Passes: " .. table.concat(stats.passes, ", "))

-- 验证
local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    io.write("Execute: ")
    f()
end

-- 统计 OP_48
local p = luac.undump(out, false)
local op48_count = 0
local function count(pp)
    for i = 1, #pp.code do
        if pp.code[i] % 64 == 48 then op48_count = op48_count + 1 end
    end
    for i = 1, #pp.p do count(pp.p[i]) end
end
count(p)
print("OP_48 count: " .. op48_count)
print("Main sizeupvalues: " .. p.sizeupvalues)
print("Main numparams: " .. p.numparams)

-- 写入文件
local fout = io.open("E:/LuaRes/luasafe/hello_full_protected.lua", "wb")
fout:write(out)
fout:close()
print("Written: E:/LuaRes/luasafe/hello_full_protected.lua")
