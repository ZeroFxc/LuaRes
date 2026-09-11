local luac = require('luac')
local src = 'local a="hello" return a'
local bc = string.dec(string.dump(load(src)))
local expected = load(bc)()

local function run(name, mods)
    local p = luac.undump(bc, false)
    for _, m in ipairs(mods) do m(p) end
    local enc = luac.dump(p)
    local f = load(enc)
    if not f then print(name, "LOADFAIL"); return end
    local ok, r = pcall(f)
    if not ok then print(name, "RUNFAIL:", r); return end
    print(name, r == expected and "PASS" or ("MISMATCH: "..tostring(r)))
end

local se = luac.str_encrypt_c
local jj = function(p) luac.junk_jmp_c(p,{count=10}) end
local jl = function(p) luac.junk_loadk_c(p,{count=10}) end
local jm = function(p) luac.junk_move_c(p,{count=10}) end
local im = luac.instruction_mutate_c
local to = luac.table_obfuscate_c
local ds = luac.debug_strip_c
local cs = luac.const_shuffle_c

run("se only", {se})
run("se+jj", {se,jj})
run("se+jl", {se,jl})
run("se+jm", {se,jm})
run("se+im", {se,im})
run("se+to", {se,to})
run("se+ds", {se,ds})
run("se+cs", {se,cs})
run("se+jj+jl+jm", {se,jj,jl,jm})
