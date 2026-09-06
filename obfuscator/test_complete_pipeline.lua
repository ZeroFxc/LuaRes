local luac = require("luac")
local protect = require("protect")

-- 编译 hello world
local func = load("print('hello world')")
local bc = string.dec(string.dump(func))
print("Original size: " .. #bc)

-- 完整 pipeline（所有 pass 都开）
local out, stats = protect.protect(bc, {
    no_strip = false,
    no_shuffle = false,
    no_mutate = false,
    no_flatten = false,
    no_opaque = false,
    no_obfuscate = false,
    no_anti_td = false,
    no_op48 = false,
    op48_count = 100,
    op48_mode = "blocks",
})

print("Protected size: " .. #out)
print("Ratio: " .. stats.ratio)
print("Passes: " .. table.concat(stats.passes, " -> "))

-- 验证
local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    io.write("Execute: ")
    f()
end

-- 详细统计
local p = luac.undump(out, false)
local total_code = 0
local op48_count = 0
local total_funcs = 0
local function scan(pp)
    total_funcs = total_funcs + 1
    total_code = total_code + #pp.code
    for i = 1, #pp.code do
        if pp.code[i] % 64 == 48 then op48_count = op48_count + 1 end
    end
    for i = 1, #pp.p do scan(pp.p[i]) end
end
scan(p)

print("\n=== Stats ===")
print("Total functions: " .. total_funcs)
print("Total instructions: " .. total_code)
print("OP_48 count: " .. op48_count)
print(string.format("OP_48 ratio: %.1f%%", op48_count / total_code * 100))
print("Main sizeupvalues: " .. p.sizeupvalues)
print("Main numparams: " .. p.numparams)
print("Main is_vararg: " .. p.is_vararg)
print("Main maxstack: " .. p.maxstacksize)
print("Main lineinfo: " .. #p.lineinfo)

-- 写入文件
local fout = io.open("E:/LuaRes/luasafe/hello_complete_protected.lua", "wb")
fout:write(out)
fout:close()
print("\nWritten: E:/LuaRes/luasafe/hello_complete_protected.lua")
