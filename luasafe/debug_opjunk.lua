local luac = require("luac")
local opaque_junk = require("opaque_junk")

local func = load("print('hello world')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

print("Original:")
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[1]="LOADK",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[30]="JMP",[34]="TEST",[36]="CALL",[38]="RETURN"}
    print(string.format("  [%d] 0x%08X %-8s A=%d sbx=%d", i, inst, names[op] or tostring(op), a, sbx))
end
print("constants:")
for i = 1, #p.k do
    print(string.format("  k[%d]: %s", i-1, tostring(p.k[i])))
end

opaque_junk.inject(p, {count = 1, recursive = false})

print("\nAfter inject 1 branch:")
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local b = (inst >> 23) & 0x1FF
    local c = (inst >> 14) & 0x1FF
    local bx = inst >> 14
    local sbx = bx - 131071
    local names = {[0]="MOVE",[1]="LOADK",[5]="GETUPVAL",[6]="GETTABUP",[7]="GETTABLE",[10]="NEWTABLE",[12]="ADD",[27]="LEN",[30]="JMP",[34]="TEST",[36]="CALL",[38]="RETURN"}
    local extra = ""
    if op == 30 then extra = string.format(" sbx=%d ->%d", sbx, i+sbx+1) end
    print(string.format("  [%2d] 0x%08X %-8s A=%d B=%d C=%d%s", i, inst, names[op] or tostring(op), a, b, c, extra))
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
