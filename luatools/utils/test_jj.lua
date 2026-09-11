local luac = require('luac')
-- Simple source, no sub-functions
local src = 'local a="hello" local b=42 return a..tostring(b)'
local bc = string.dec(string.dump(load(src)))
local expected = load(bc)()

local function run(name, mods)
    local p = luac.undump(bc, false)
    for _, m in ipairs(mods) do m(p) end
    local enc = luac.dump(p)
    local f = load(enc)
    if not f then print(name, "LOADFAIL"); return end
    local ok, r = pcall(f)
    if not ok then print(name, "RUNFAIL:", tostring(r):sub(1,80)); return end
    print(name, r == expected and "PASS" or ("MISMATCH: "..tostring(r)))
end

local se = luac.str_encrypt_c
local jj = function(p) luac.junk_jmp_c(p,{count=20}) end

run("base", {})
run("se", {se})
run("jj", {jj})
run("se+jj", {se,jj})

-- Also test jj alone on source with loops
local src2 = 'local s=0 for i=1,10 do s=s+i end return s'
local bc2 = string.dec(string.dump(load(src2)))
local expected2 = load(bc2)()
local p2 = luac.undump(bc2, false)
luac.junk_jmp_c(p2, {count=30})
local r2 = load(luac.dump(p2))()
print("loop+jj:", r2 == expected2 and "PASS" or ("MISMATCH: "..tostring(r2).." expected "..tostring(expected2)))
