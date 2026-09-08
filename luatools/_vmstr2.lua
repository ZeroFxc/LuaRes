local luac = require("luac")
local code = [[
print("hello world")
local s = "test string"
print(s)
]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.str_encrypt_c(p)
print("after se: code="..p.sizecode.." k="..p.sizek)
luac.vm_embed_c(p)
print("after vm: code="..p.sizecode.." k="..p.sizek)
local d = luac.dump(p)
print("dump size="..#d)
p = nil
local r, err = load(d)
if not r then print("LOAD FAIL: "..tostring(err)); os.exit(1) end
print("EXEC:")
r()
print("DONE")
