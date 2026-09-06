local f = io.open('C:/Users/ruilo/Downloads/main(3).lua', 'rb')
local data = f:read('*a')
f:close()
print('input size:', #data)
print('first 20 chars:', data:sub(1, 20))

local ok, dec = pcall(string.dec, data)
print('dec ok:', ok, 'size:', dec and #dec or 'nil')
if dec then
    print('dec first 16 bytes:', (dec:sub(1,16):gsub('.', function(c) return string.format('%02X ', string.byte(c)) end)))
    local ok2, proto = pcall(luac.undump, dec, false)
    print('undump ok:', ok2, type(proto))
    if not ok2 then print('err:', proto) end
end
