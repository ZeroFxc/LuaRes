local luac = require("luac")
local junk_loadk = require("junk_loadk")

local func = load("print('hello world')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

print("Original:")
print("maxstacksize: " .. p.maxstacksize)
print("constants: " .. #p.k)
for i = 1, #p.k do
    print(string.format("  k[%d]: %s", i-1, tostring(p.k[i])))
end
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    print(string.format("  [%d] 0x%08X op=%d A=%d Bx=%d", i, inst, op, a, bx))
end

junk_loadk.inject(p, {count = 5, recursive = false})

print("\nAfter inject 5 LOADK:")
print("maxstacksize: " .. p.maxstacksize)
print("constants: " .. #p.k)
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local names = {[1]="LOADK",[6]="GETTABUP",[36]="CALL",[38]="RETURN"}
    print(string.format("  [%d] 0x%08X %-8s A=%d Bx=%d", i, inst, names[op] or tostring(op), a, bx))
end

local out = luac.dump(p)
local ok, f = pcall(load, out)
print("\nLoad: " .. tostring(ok))
if ok then
    print("Execute:")
    f()
else
    print("Error: " .. tostring(f))
end
