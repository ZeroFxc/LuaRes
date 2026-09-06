local luac = require('luac')
local src = 'local a="hello" local b=42 local t={x=1} return a..tostring(b)..t.x'
local bc = string.dec(string.dump(load(src)))
local expected = load(bc)()

local function run(mods)
    local p = luac.undump(bc, false)
    for _, m in ipairs(mods) do m(p) end
    local enc = luac.dump(p)
    local f = load(enc)
    if not f then return "LOADFAIL" end
    local ok, r = pcall(f)
    if not ok then return "RUNFAIL" end
    return r == expected and "PASS" or "MISMATCH"
end

local se = luac.str_encrypt_c
local cs = luac.const_shuffle_c
local bo = luac.bool_obfuscate_c
local to = luac.table_obfuscate_c
local im = luac.instruction_mutate_c
local op = luac.opaque_predicate_c

print("op alone:", run({op}))
print("se+op:", run({se,op}))
print("cs+op:", run({cs,op}))
print("bo+op:", run({bo,op}))
print("to+op:", run({to,op}))
print("im+op:", run({im,op}))
print("se+cs+op:", run({se,cs,op}))
print("se+to+op:", run({se,to,op}))
print("to+im+op:", run({to,im,op}))
