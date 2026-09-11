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

local function test(name, fn)
    local p = luac.undump(bc, false)
    fn(p)
    local enc = luac.dump(p)
    local f = load(enc)
    if not f then print(name, "LOAD FAIL"); return end
    local ok, r = pcall(f)
    if not ok then print(name, "RUN FAIL:", r); return end
    print(name, r == expected and "PASS" or ("MISMATCH: "..tostring(r)))
end

test("str_encrypt", luac.str_encrypt_c)
test("const_hide", luac.const_hide_c)
test("const_shuffle", luac.const_shuffle_c)
test("num_obfuscate", luac.num_obfuscate_c)
test("bool_obfuscate", luac.bool_obfuscate_c)
test("table_obfuscate", luac.table_obfuscate_c)
test("instruction_mutate", luac.instruction_mutate_c)
test("opaque_predicate", luac.opaque_predicate_c)
test("junk_jmp", function(p) luac.junk_jmp_c(p,{count=20}) end)
test("junk_loadk", function(p) luac.junk_loadk_c(p,{count=20}) end)
test("junk_move", function(p) luac.junk_move_c(p,{count=20}) end)
test("op48_junk", luac.op48_junk_c)
test("const_poison", function(p) luac.const_poison_c(p,{count=3}) end)
test("debug_strip", luac.debug_strip_c)
