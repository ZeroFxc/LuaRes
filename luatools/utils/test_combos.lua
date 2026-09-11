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

local se = luac.str_encrypt_c
local cs = luac.const_shuffle_c
local bo = luac.bool_obfuscate_c
local to = luac.table_obfuscate_c
local im = luac.instruction_mutate_c
local op = luac.opaque_predicate_c
local jj = function(p) luac.junk_jmp_c(p,{count=20}) end
local jl = function(p) luac.junk_loadk_c(p,{count=20}) end
local jm = function(p) luac.junk_move_c(p,{count=20}) end
local ds = luac.debug_strip_c

local function run(name, mods)
    local p = luac.undump(bc, false)
    for _, m in ipairs(mods) do m(p) end
    local enc = luac.dump(p)
    local f = load(enc)
    if not f then print(name, "LOADFAIL"); return end
    local ok, r = pcall(f)
    if not ok then print(name, "RUNFAIL:", tostring(r):sub(1,60)); return end
    print(name, r == expected and "PASS" or ("MISMATCH: "..tostring(r):sub(1,40)))
end

run("base", {})
run("se", {se})
run("se+jj", {se,jj})
run("se+jl", {se,jl})
run("se+jm", {se,jm})
run("se+op", {se,op})
run("se+im", {se,im})
run("se+to", {se,to})
run("se+cs", {se,cs})
run("se+jj+op", {se,jj,op})
run("se+jj+im", {se,jj,im})
run("se+op+im", {se,op,im})
run("se+jj+jl+jm", {se,jj,jl,jm})
run("se+op+jj+jl+jm", {se,op,jj,jl,jm})
run("se+to+im+op+jj", {se,to,im,op,jj})
run("all-no-ds", {se,cs,bo,to,im,op,jj,jl,jm})
run("all", {se,cs,bo,to,im,op,jj,jl,jm,ds})
