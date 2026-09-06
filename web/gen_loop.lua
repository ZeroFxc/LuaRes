local f = loadfile("E:/LuaRes/web/test_loop.lua")
local dump = string.dump(f, true)
-- string.dec decompresses if compressed
local ok, dec = pcall(function() return string.dec(dump) end)
if ok and dec then dump = dec end
local out = io.open("E:/LuaRes/web/test_loop.luac", "wb")
out:write(dump)
out:close()
print("written", #dump, "bytes")
