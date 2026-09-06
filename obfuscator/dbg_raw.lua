local luac = require("luac")
local src = 'local a = "hello world"; print(a)'
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
require('str_split').obfuscate(proto)

print("=== k in Lua table ===")
for i=1,#proto.k do
    local s = tostring(proto.k[i])
    local bytes = s:gsub('.', function(c) return string.format("%02x ", c:byte()) end)
    print(string.format("  k[%d] = '%s' bytes: %s", i-1, s, bytes))
end

local enc = luac.dump(proto)
local f = io.open("dbg_raw.luac", "wb")
f:write(enc)
f:close()
print("\nwrote", #enc, "bytes to dbg_raw.luac")
