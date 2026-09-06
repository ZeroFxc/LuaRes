local f = io.open('C:/Users/ruilo/Downloads/main(3).lua', 'rb')
local data = f:read('*a')
f:close()
local dec = string.dec(data)
print('dec size:', #dec)
-- 打印末尾 100 字节
local start = #dec - 100
for i = start, #dec do
    io.write(string.format('%02X ', string.byte(dec, i)))
    if (i - start + 1) % 16 == 0 then io.write('\n') end
end
io.write('\n')
