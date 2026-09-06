local protect = require("protect")
local luac = require("luac")

local func = loadfile("test_multi_func.lua")
local bc = string.dec(string.dump(func))
local prot = protect(bc)
print("Protected: " .. #prot .. " bytes")

local p = luac.undump(prot, false)
print("Undump OK, functions: " .. #p.p)

print("Calling deop48...")
local r1 = require("deop48").remove(p)
print("deop48 removed: " .. r1)

print("Calling dejunk_jmp...")
local r2 = require("dejunk_jmp").remove(p)
print("dejunk_jmp removed: " .. r2)

print("Calling deopaque_junk...")
local r3 = require("deopaque_junk").remove(p)
print("deopaque_junk removed: " .. r3)

print("Calling dejunk_loadk...")
local r4 = require("dejunk_loadk").remove(p)
print("dejunk_loadk removed: " .. r4)

print("Calling dejunk_move...")
local r5 = require("dejunk_move").remove(p)
print("dejunk_move removed: " .. r5)

print("Calling fix_antidec...")
local r6 = require("fix_antidec").fix(p)
print("fix_antidec done: " .. r6)

print("Dumping...")
local out = luac.dump(p)
print("Dump OK: " .. #out .. " bytes")

local ok, f = pcall(load, out)
print("Load: " .. tostring(ok))
if ok then
    local old = print
    print = function() end
    local exec_ok, err = pcall(f)
    print = old
    print("Exec: " .. tostring(exec_ok))
    if not exec_ok then print("Error: " .. tostring(err)) end
end
