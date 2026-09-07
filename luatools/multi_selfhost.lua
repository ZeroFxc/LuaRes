-- multi_selfhost.lua - 多层嵌套自举测试
package.path = '../luatools/?.lua;' .. package.path
local VM = require('vm_gen')
local luac = require('luac')
local vm_pack = require('forward.vm_pack')

-- 把 vm_gen.lua 编译打包成 VM 可加载的 table 格式
local function pack_vm_source()
    local f = loadfile('../luatools/vm_gen.lua')
    local bc = string.dec(string.dump(f, true))
    local proto = luac.undump(bc, true)
    return vm_pack.pack(proto)
end

local function pack_src(src)
    local f = load(src)
    local bc = string.dec(string.dump(f, true))
    local proto = luac.undump(bc, true)
    return vm_pack.pack(proto)
end

local vm_chunk = pack_vm_source()

print('=== Layer 0: host Lua ===')
print('  加载 vm_gen.lua 得到外层 VM')

print('=== Layer 1: 外层 VM 运行 vm_gen.lua ===')
local inner1 = VM.exec(vm_chunk)
print('  inner1 type:', type(inner1), 'exec:', type(inner1.exec))

print('=== Layer 2: 内层 VM 再运行 vm_gen.lua ===')
local inner2 = inner1.exec(vm_chunk)
print('  inner2 type:', type(inner2), 'exec:', type(inner2.exec))

print('=== Layer 3: 第三层 VM 执行脚本 ===')
local r3 = inner2.exec(pack_src('return 40 + 2'))
print('  layer3 result:', r3)
print('  3层嵌套自举:', r3 == 42 and 'PASS' or 'FAIL')

print('=== Layer 4: 第四层 ===')
local inner3 = inner2.exec(vm_chunk)
local r4 = inner3.exec(pack_src('return "deep vm works"'))
print('  layer4 result:', r4)
print('  4层嵌套自举:', r4 == "deep vm works" and 'PASS' or 'FAIL')
