local f = load([[
print("hello from wasm test")
print(6*7)
local t = {a=1, b=2}
print(t.a + t.b)
]])
local bc = string.dec(string.dump(f, false), false)
local out = io.open("E:/LuaRes/web/test.luac", "wb")
out:write(bc)
out:close()
print("test.luac written: " .. #bc .. " bytes")
-- verify first bytes
local bytes = {string.byte(bc, 1, 4)}
print("header: " .. table.concat(bytes, " "))
