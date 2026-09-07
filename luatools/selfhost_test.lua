-- selfhost_test.lua - VM 自举测试
-- 用法: ..\luasafe\lua_luac_c.exe selfhost_test.lua
package.path = '../luatools/?.lua;' .. package.path
local VM = require('vm_gen')
local luac = require('luac')
local vm_pack = require('forward.vm_pack')

local function pack_src(src)
    local f = load(src)
    local bc = string.dec(string.dump(f, true))
    local proto = luac.undump(bc, true)
    return vm_pack.pack(proto)
end

print('=== 1. 基础测试 ===')
VM.exec(pack_src('print(1+2); print("hello")'))

print('=== 2. 闭包测试 ===')
VM.exec(pack_src('local function mk() local x=0 return function() x=x+1 return x end end; local c=mk(); print(c()); print(c())'))

print('=== 3. pcall 测试 ===')
VM.exec(pack_src('local ok, err = pcall(function() error("test err") end); print(ok, err)'))

print('=== 4. 协程测试 ===')
VM.exec(pack_src([[
local co = coroutine.create(function()
    for i = 1, 3 do coroutine.yield(i) end
end)
print(coroutine.resume(co))
print(coroutine.resume(co))
print(coroutine.resume(co))
print(coroutine.resume(co))
]]))

print('=== 5. 自举测试 ===')
-- 把 vm_gen.lua 本身编译打包，在外层 VM 里运行，得到内层 VM
local vm_src = loadfile('../luatools/vm_gen.lua')
local vm_bc = string.dec(string.dump(vm_src, true))
local vm_proto = luac.undump(vm_bc, true)
local vm_chunk = vm_pack.pack(vm_proto)

local inner_VM = VM.exec(vm_chunk)
print('inner VM type:', type(inner_VM), 'exec:', type(inner_VM.exec))

-- 用内层 VM 执行脚本
local result = inner_VM.exec(pack_src('return 6 * 7'))
print('inner VM result:', result)
print('self-hosting:', result == 42 and 'PASS' or 'FAIL')
