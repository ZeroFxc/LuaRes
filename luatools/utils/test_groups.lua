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
    if not ok then return "RUNFAIL: "..tostring(r) end
    return r == expected and "PASS" or ("MISMATCH: "..tostring(r))
end

local se = luac.str_encrypt_c
local cs = luac.const_shuffle_c
local bo = luac.bool_obfuscate_c
local to = luac.table_obfuscate_c
local im = luac.instruction_mutate_c
local op = luac.opaque_predicate_c
local jj = function(p) luac.junk_jmp_c(p,{count=10}) end
local jl = function(p) luac.junk_loadk_c(p,{count=10}) end
local jm = function(p) luac.junk_move_c(p,{count=10}) end
local ds = luac.debug_strip_c

print("G1 core:", run({se,cs,bo,to,im}))
print("G2 +opaque:", run({se,cs,bo,to,im,op}))
print("G3 +junk:", run({se,cs,bo,to,im,op,jj,jl,jm}))
print("G4 +strip:", run({se,cs,bo,to,im,op,jj,jl,jm,ds}))
print("junk only:", run({jj,jl,jm}))
print("se+junk:", run({se,jj,jl,jm}))
