local luac = require("luac")

local func = load("local function f(n) if n <= 1 then return n end return 0 end return f")
local bc = string.dec(string.dump(func))
local p = luac.undump(bc, false)

print("main proto:")
for i = 1, #p.code do
    local inst = p.code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    print(string.format("  [%d] 0x%08X op=%d A=%d", i, inst, op, a))
end

print("\nf (p[1]) proto:")
for i = 1, #p.p[1].code do
    local inst = p.p[1].code[i]
    local op = inst % 64
    local a = (inst >> 6) & 0xFF
    local b = (inst >> 23) & 0x1FF
    local c = (inst >> 14) & 0x1FF
    local bx = inst >> 14
    local sbx = bx - 131071
    print(string.format("  [%d] 0x%08X op=%d A=%d B=%d C=%d sbx=%d", i, inst, op, a, b, c, sbx))
end

print("\nf constants:")
for i = 1, #p.p[1].k do
    print(string.format("  k[%d]: %s", i-1, tostring(p.p[1].k[i])))
end

print("\nf upvalues:")
for i = 1, #p.p[1].upvalues do
    local uv = p.p[1].upvalues[i]
    print(string.format("  uv[%d]: instack=%s idx=%s name=%s", i-1, tostring(uv.instack), tostring(uv.idx), tostring(uv.name)))
end
