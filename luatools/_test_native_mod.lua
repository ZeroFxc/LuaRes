-- Test native str_encrypt and vm_embed
local luac = require("luac")

local src = "print(6)\n"
local bc = string.dec(string.dump(load(src), true))
print("bytecode size:", #bc)

-- Test str_encrypt
local ok, p = pcall(luac.undump, bc, false)
if not ok then
    print("undump failed:", p)
    return
end
print("undump ok, proto type:", type(p))

-- Apply str_encrypt
local ok2, err = pcall(function()
    local mod = require("modules.str_encrypt")
    return mod.apply(p)
end)
print("str_encrypt apply:", ok2, err)

-- Dump and run
local out = luac.dump(p)
print("dump size:", #out)
local fn = load(out)
if fn then
    fn()
else
    print("load failed")
end
