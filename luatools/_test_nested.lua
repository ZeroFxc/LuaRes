-- 嵌套打包测试：把 a_vm.lua 再次混淆
local luac = require("luac")

-- 读取 a_vm.lua
local f = io.open("a_vm.lua", "rb")
local src = f:read("*a")
f:close()

print("Input size:", #src)

-- 编译为字节码
local bc = luac.compile(src)
print("Compiled bytecode size:", #bc)

-- 加载字节码
local handle = luac.load(bc)
print("Handle:", handle)

-- 应用模块
local modules = {"str_encrypt", "str_split"}
for i, mod in ipairs(modules) do
    local ok, err = luac.apply_module(handle, mod)
    print("["..i.."/"..#modules.."] "..mod..": "..(ok and "OK" or "FAIL: "..tostring(err)))
    if not ok then os.exit(1) end
end

-- 导出字节码
local out_bc = luac.dump(handle)
print("Obfuscated bytecode size:", #out_bc)

-- 现在用 vm_embed 生成自包含VM
local ok, err = luac.apply_module(handle, "vm_embed_c")
print("vm_embed_c:", ok and "OK" or "FAIL: "..tostring(err))
if not ok then os.exit(1) end

-- 导出结果（Lua源码）
local result = luac.dump(handle)
print("VM embed output size:", #result)

-- 保存
local f2 = io.open("a_vm_nested.lua", "wb")
f2:write(result)
f2:close()
print("Saved to a_vm_nested.lua")

-- 运行测试
print("\n=== Running nested VM ===")
local fn, err = load(result)
if not fn then
    print("Load error:", err)
    os.exit(1)
end
local ok2, err2 = pcall(fn)
if not ok2 then
    print("Run error:", err2)
else
    print("Run OK")
end
