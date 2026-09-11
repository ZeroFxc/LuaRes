local luac = require('luac')
local src = [[
local function add(a,b) return a+b end
local t = {x=1, y=2, z="hello"}
local n = 42
local s = "world"
t.w = n
local r = add(t.x, t.y) + n
return r .. t.z .. s .. tostring(t.w)
]]
local bc = string.dec(string.dump(load(src)))
local p = luac.undump(bc, false)
local expected = load(bc)()

-- Run ALL C modules
luac.str_encrypt_c(p)
luac.const_hide_c(p)
luac.const_shuffle_c(p)
luac.num_obfuscate_c(p)
luac.bool_obfuscate_c(p)
luac.table_obfuscate_c(p)
luac.instruction_mutate_c(p)
luac.opaque_predicate_c(p)
luac.junk_jmp_c(p, {count=20})
luac.junk_loadk_c(p, {count=20})
luac.junk_move_c(p, {count=20})
luac.op48_junk_c(p)
luac.const_poison_c(p, {count=3})
luac.debug_strip_c(p)
-- antidec requires andlua VM (poisoned header breaks standard Lua)

local enc = luac.dump(p)
local f = load(enc)
if not f then
    print("LOAD FAILED")
    os.exit(1)
end
local result = f()
print("expected:", expected)
print("result:  ", result)
print(result == expected and "ALL MODULES PASS" or "MISMATCH")
