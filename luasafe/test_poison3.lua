local luac = require('luac')

-- 编译一个简单函数
local func = load('local a = 1; local b = "hello"; return a .. b')
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('Original sizek:', #proto.k)
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end

-- 在常量池末尾添加投毒常量
-- {__poison = 0x99} 会被 dump 为单个字节 0x99
-- andlua 遇到非法 tag 不读数据，所以这个常量只占 1 字节
proto.k[#proto.k + 1] = {__poison = 0x99}

print('After poison sizek:', #proto.k)

-- dump
local poisoned_bc = luac.dump(proto)
print('Original size:', #bc)
print('Poisoned size:', #poisoned_bc)

-- 测试加载
local ok, err = pcall(load, poisoned_bc)
if ok then
    print('Load OK!')
    local ok2, result = pcall(err)
    if ok2 then
        print('Run OK! result:', tostring(result))
    else
        print('Run failed:', result)
    end
else
    print('Load failed:', err)
end

-- 用 luaclib 重新解析看看
local ok3, proto2 = pcall(luac.undump, poisoned_bc, false)
if ok3 then
    print('luaclib re-parse OK, sizek:', #proto2.k)
    for i = 1, #proto2.k do
        print('  [' .. i .. ']', type(proto2.k[i]), tostring(proto2.k[i]))
    end
else
    print('luaclib re-parse failed:', proto2)
end

-- 测试多个投毒常量
print()
print('=== Testing multiple poison constants ===')
local func2 = load('return 1 + 2')
local bc2 = string.dec(string.dump(func2))
local proto3 = luac.undump(bc2, false)
print('Original sizek:', #proto3.k)

-- 添加 10 个投毒常量，使用不同的 tag
for i = 1, 10 do
    proto3.k[#proto3.k + 1] = {__poison = 0x80 + i}
end
print('After poison sizek:', #proto3.k)

local poisoned_bc2 = luac.dump(proto3)
print('Poisoned size:', #poisoned_bc2)

local ok4, err4 = pcall(load, poisoned_bc2)
if ok4 then
    print('Load OK!')
    local ok5, result = pcall(err4)
    if ok5 then
        print('Run OK! result:', tostring(result))
    else
        print('Run failed:', result)
    end
else
    print('Load failed:', err4)
end
