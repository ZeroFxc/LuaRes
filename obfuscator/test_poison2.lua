-- 测试常量池投毒：非法 tag + 数据被后续常量吸收
local luac = require('luac')

-- 编译一个简单函数
local func = load('local a = 1; local b = "hello"; return a .. b')
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)

print('Original sizek:', #proto.k)
for i = 1, #proto.k do
    print('  [' .. i .. ']', type(proto.k[i]), tostring(proto.k[i]))
end

-- dump 原始字节码
local orig_bc = luac.dump(proto)

-- 找到常量池的位置（用 luaclib 解析后的信息手动定位）
-- 先重新解析获取精确位置
local pos = 34
-- source (LoadString format)
local size = orig_bc:byte(pos)
pos = pos + 1
if size == 0xFF then
    local s = 0
    for i = 0, 3 do s = s + orig_bc:byte(pos+i) * (256^i) end
    pos = pos + 4
    size = s
end
if size > 0 then pos = pos + (size - 1) end
-- linedefined + lastlinedefined
pos = pos + 8
-- numparams + is_vararg + maxstacksize
pos = pos + 3
-- code size + code
local code_size = string.unpack('<I4', orig_bc, pos)
pos = pos + 4 + code_size * 4
-- 现在是 sizek
local sizek_pos = pos
local sizek = string.unpack('<I4', orig_bc, pos)
print('sizek at pos', sizek_pos, '=', sizek)
pos = pos + 4

-- 读取所有常量，记录每个常量的位置和长度
local consts = {}
for i = 1, sizek do
    local start = pos
    local tag = orig_bc:byte(pos)
    if tag == 0 then pos = pos + 1
    elseif tag == 1 then pos = pos + 2
    elseif tag == 3 then pos = pos + 9
    elseif tag == 19 then pos = pos + 9
    elseif tag == 4 or tag == 20 then
        local slen = orig_bc:byte(pos+1)
        local p = pos + 2
        if slen == 0xFF then
            slen = 0
            for j = 0, 3 do slen = slen + orig_bc:byte(p+j) * (256^j) end
            p = p + 4
        end
        if slen > 0 then p = p + (slen - 1) end
        pos = p
    else
        print('Unknown tag at const', i, ':', tag)
        pos = pos + 1 -- andlua behavior: skip only tag byte
    end
    consts[i] = {start=start, tag=tag, len=pos-start}
end
print('Last const ends at pos', pos)

-- 现在在常量池末尾添加投毒：
-- 非法 tag (0x99) + 2字节数据 (0x01 0x00 = boolean false)
-- 这 2 字节会被 1 个 boolean 常量吸收
-- sizek 需要 +1（投毒tag占1个常量位置，吸收的boolean占1个？不对...）

-- 实际上：andlua 遇到非法 tag 时，不读数据，直接处理下一个常量
-- 所以非法 tag 占 1 个常量位置（sizek 中的一个），但不消耗数据字节
-- 下一个常量的 tag 就是非法 tag 后面的第一个字节

-- 如果我添加：tag=0x99 + 0x01 + 0x00
-- andlua 处理：
--   常量 N: tag=0x99 (非法, 不读数据)
--   常量 N+1: tag=0x01 (boolean, 读1字节值=0x00=false)
-- 所以 sizek 需要 +2

-- 构造投毒数据
local poison_tag = 0x99
local poison_data = string.char(0x01, 0x00) -- boolean false

-- 在常量池末尾插入
local before = orig_bc:sub(1, pos-1)
local after = orig_bc:sub(pos)
local poisoned = before .. string.char(poison_tag) .. poison_data .. after

-- 修改 sizek: +2
local new_sizek = sizek + 2
poisoned = poisoned:sub(1, sizek_pos-1) .. string.pack('<I4', new_sizek) .. poisoned:sub(sizek_pos+4)

print('Original size:', #orig_bc)
print('Poisoned size:', #poisoned)
print('New sizek:', new_sizek)

-- 保存
local f = io.open('E:/LuaRes/luasafe/test_poison2.luac', 'wb')
f:write(poisoned)
f:close()

-- 测试加载
local ok, err = pcall(load, poisoned)
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

-- 用 luaclib 解析看看
local ok3, proto2 = pcall(luac.undump, poisoned, false)
if ok3 then
    print('luaclib parse OK, sizek:', #proto2.k)
    for i = 1, #proto2.k do
        print('  [' .. i .. ']', type(proto2.k[i]), tostring(proto2.k[i]))
    end
else
    print('luaclib parse failed:', proto2)
end
