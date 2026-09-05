-- 分析 TitanShield 常量池的原始字节结构（修正字符串格式）
local f = io.open('E:/LuaRes/TitanShield.lua', 'rb')
local data = f:read('*a')
f:close()

local function read_string(data, pos)
    local size = data:byte(pos)
    pos = pos + 1
    if size == 0xFF then
        size = 0
        for i = 0, 3 do
            size = size + data:byte(pos + i) * (256 ^ i)
        end
        pos = pos + 4
    end
    if size == 0 then return nil, pos end
    local len = size - 1
    local s = data:sub(pos, pos + len - 1)
    return s, pos + len
end

local pos = 34
-- source string
local source
source, pos = read_string(data, pos)
print('source:', source and source:sub(1, 60) or 'nil')
-- linedefined (4), lastlinedefined (4)
pos = pos + 8
-- numparams, is_vararg, maxstacksize
pos = pos + 3
-- code: sizecode (4) + code * 4
local code_size = string.unpack('<I4', data, pos)
print('code size:', code_size)
pos = pos + 4 + code_size * 4
-- constants
local sizek = string.unpack('<I4', data, pos)
print('sizek:', sizek)
pos = pos + 4

print()
print('Parsing constants:')
local unknown_count = 0
local unknown_tags = {}
for i = 1, sizek do
    if pos > #data then
        print('OUT OF BOUNDS at i=' .. i .. ' pos=' .. pos)
        break
    end
    local tag = data:byte(pos)
    if tag == 0 then -- nil
        pos = pos + 1
    elseif tag == 1 then -- boolean
        pos = pos + 2
    elseif tag == 3 then -- float
        pos = pos + 1 + 8
    elseif tag == 19 then -- int
        pos = pos + 1 + 8
    elseif tag == 4 or tag == 20 then -- string
        local s
        s, pos = read_string(data, pos + 1)
    else
        unknown_count = unknown_count + 1
        unknown_tags[tag] = (unknown_tags[tag] or 0) + 1
        if unknown_count <= 15 then
            local next_bytes = {}
            for j = 1, math.min(6, #data-pos) do
                table.insert(next_bytes, string.format('%02X', data:byte(pos+j)))
            end
            print(string.format('  [%4d] tag=%3d(0x%02X) UNKNOWN, next: %s', i, tag, tag, table.concat(next_bytes, ' ')))
        end
        -- andlua 遇到非法 tag 不读数据，直接 break
        -- 所以只跳过 tag 字节
        pos = pos + 1
    end
end

print()
print('Total unknown tags:', unknown_count)
print('Unknown tag distribution:')
for tag, count in pairs(unknown_tags) do
    print(string.format('  tag %3d(0x%02X): %d times', tag, tag, count))
end
print('Final pos:', pos, 'of', #data)
print('Remaining bytes:', #data - pos + 1)

-- 看看剩余字节的开头
if pos <= #data then
    print('Remaining bytes start:')
    for j = 1, math.min(32, #data-pos+1) do
        io.write(string.format('%02X ', data:byte(pos+j-1)))
        if j % 16 == 0 then io.write('\n') end
    end
    io.write('\n')
end
