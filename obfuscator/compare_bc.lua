local luac = require('luac')
local f = io.open('C:/Users/ruilo/Downloads/tk.lua', 'rb')
local orig = f:read('*a')
f:close()

local p = luac.undump(orig, false)
local dumped = luac.dump(p)

print('orig size:', #orig, 'dumped size:', #dumped)

-- 逐字节比较，找第一个不同的位置
local diff_start = -1
local diff_count = 0
for i = 1, math.min(#orig, #dumped) do
    if orig:byte(i) ~= dumped:byte(i) then
        if diff_start == -1 then diff_start = i end
        diff_count = diff_count + 1
    end
end
print('first diff at byte:', diff_start)
print('total diff bytes in overlap:', diff_count)

-- 打印差异点附近的原始和dump数据
if diff_start > 0 then
    local s = math.max(1, diff_start - 16)
    local e = math.min(#orig, diff_start + 32)
    io.write('orig  [' .. s .. '-' .. e .. ']: ')
    for i = s, e do io.write(string.format('%02X ', orig:byte(i))) end
    io.write('\n')
    io.write('dumped[' .. s .. '-' .. math.min(#dumped, e) .. ']: ')
    for i = s, math.min(#dumped, e) do io.write(string.format('%02X ', dumped:byte(i))) end
    io.write('\n')
end
