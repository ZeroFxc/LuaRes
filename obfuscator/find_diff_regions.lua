local luac = require('luac')
local f = io.open('C:/Users/ruilo/Downloads/tk.lua', 'rb')
local orig = f:read('*a')
f:close()
local p = luac.undump(orig, false)
local dumped = luac.dump(p)

-- 找出差异区间
local diffs = {}
local in_diff = false
local diff_start = 0
for i = 1, math.min(#orig, #dumped) do
    if orig:byte(i) ~= dumped:byte(i) then
        if not in_diff then
            diff_start = i
            in_diff = true
        end
    else
        if in_diff then
            table.insert(diffs, {start=diff_start, end_=i-1, len=i-diff_start})
            in_diff = false
            if #diffs >= 20 then break end
        end
    end
end
if in_diff then table.insert(diffs, {start=diff_start, end_=math.min(#orig,#dumped), len=math.min(#orig,#dumped)-diff_start+1}) end

for i, d in ipairs(diffs) do
    print(string.format('diff #%d: [%d-%d] len=%d', i, d.start, d.end_, d.len))
    -- 打印原始和dump的前16字节
    io.write('  orig: ')
    for j = d.start, math.min(d.start+15, #orig) do io.write(string.format('%02X ', orig:byte(j))) end
    io.write('\n  dump: ')
    for j = d.start, math.min(d.start+15, #dumped) do io.write(string.format('%02X ', dumped:byte(j))) end
    io.write('\n')
end
