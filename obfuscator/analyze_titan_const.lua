-- 分析 TitanShield 常量池的原始字节结构
local f = io.open('E:/LuaRes/TitanShield.lua', 'rb')
local data = f:read('*a')
f:close()

-- 用 luaclib 解析获取函数结构信息
local luac = require('luac')
local proto = luac.undump(data, false)

print('Main sizek:', proto.sizek or #proto.k)
print('Main sizep:', proto.sizep or #proto.p)

-- 直接在字节码中找到 main 函数的常量池
-- header 33 bytes
-- function: source(LoadString) + linedefined(4) + lastlinedefined(4) + numparams(1) + is_vararg(1) + maxstacksize(1) + code(LoadCode) + constants...

local pos = 34
-- LoadString: size_t (4 bytes) + string
local src_len = string.unpack('<I4', data, pos)
print('source len:', src_len)
pos = pos + 4 + src_len
-- linedefined, lastlinedefined
pos = pos + 8
-- numparams, is_vararg, maxstacksize
pos = pos + 3
-- LoadCode: sizecode (4) + code * 4
local code_size = string.unpack('<I4', data, pos)
print('code size:', code_size)
pos = pos + 4 + code_size * 4
-- 现在是常量池
local sizek = string.unpack('<I4', data, pos)
print('sizek at pos', pos, '=', sizek)
pos = pos + 4

print()
print('Parsing constants (raw):')
local unknown_count = 0
for i = 1, math.min(sizek, 200) do
    local tag = data:byte(pos)
    local tag_str = string.format('%d(0x%02X)', tag, tag)
    if tag == 0 then -- nil
        pos = pos + 1
        if i <= 20 then print(string.format('  [%3d] %-12s nil', i, tag_str)) end
    elseif tag == 1 then -- boolean
        local v = data:byte(pos+1)
        pos = pos + 2
        if i <= 20 then print(string.format('  [%3d] %-12s bool=%s', i, tag_str, tostring(v==1))) end
    elseif tag == 3 then -- float
        pos = pos + 1 + 8
        if i <= 20 then print(string.format('  [%3d] %-12s float', i, tag_str)) end
    elseif tag == 19 then -- int
        pos = pos + 1 + 8
        if i <= 20 then print(string.format('  [%3d] %-12s int', i, tag_str)) end
    elseif tag == 4 or tag == 20 then -- string
        local slen = string.unpack('<I4', data, pos+1)
        local s = data:sub(pos+5, pos+4+slen)
        pos = pos + 1 + 4 + slen
        if i <= 20 then
            local display = s:sub(1, 40)
            if #s > 40 then display = display .. '...' end
            print(string.format('  [%3d] %-12s string len=%d: %s', i, tag_str, slen, display))
        end
    else
        unknown_count = unknown_count + 1
        -- 看看后面的数据
        local next_bytes = {}
        for j = 1, math.min(8, #data-pos) do
            table.insert(next_bytes, string.format('%02X', data:byte(pos+j)))
        end
        if unknown_count <= 10 or i <= 200 then
            print(string.format('  [%3d] %-12s UNKNOWN! next bytes: %s', i, tag_str, table.concat(next_bytes, ' ')))
        end
        -- 关键：andlua 遇到非法 tag 不读数据，直接 break
        -- 所以下一个常量的 tag 就是 pos+1
        -- 让我们看看 pos+1 是什么
        local next_tag = data:byte(pos+1)
        if unknown_count <= 10 then
            print(string.format('         next pos tag would be: %d(0x%02X)', next_tag, next_tag))
        end
        pos = pos + 1 -- 只跳过 tag 字节，模拟 andlua 的行为
    end
end

print()
print('Unknown tags found in first 200:', unknown_count)
print('Final pos after parsing first 200:', pos)
print('Expected pos (if all valid):', 'depends on data')
