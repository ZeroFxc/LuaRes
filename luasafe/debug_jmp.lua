local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = load("print('hello')")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

print("Original:")
for i = 1, #p.code do
    local op = p.code[i] % 64
    print(string.format("  [%d] 0x%08X op=%d", i, p.code[i], op))
end

junk_jmp.inject(p, {count = 5, recursive = false})

print("\nAfter inject:")
for i = 1, #p.code do
    local op = p.code[i] % 64
    local bx = p.code[i] >> 14
    local sbx = bx - 131071
    print(string.format("  [%d] 0x%08X op=%d sbx=%d", i, p.code[i], op, sbx))
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
