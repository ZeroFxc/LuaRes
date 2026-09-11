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
local expected = load(bc)()
local p = luac.undump(bc, false)
luac.str_encrypt_c(p)
luac.const_shuffle_c(p)
luac.bool_obfuscate_c(p)
luac.table_obfuscate_c(p)
luac.instruction_mutate_c(p)
luac.opaque_predicate_c(p)
luac.junk_jmp_c(p, {count=20})
luac.junk_loadk_c(p, {count=20})
luac.junk_move_c(p, {count=20})
-- op48_junk/const_poison need andlua VM to ignore invalid opcodes/tags
luac.debug_strip_c(p)
local enc = luac.dump(p)
local f = load(enc)
local result = f()
print("expected:", expected)
print("result:  ", result)
print(result == expected and "COMBINED PASS" or "MISMATCH")
