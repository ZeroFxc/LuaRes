-- 验证cfg_shuffle字节码变更：对比混淆前后opcode分布和JMP数量
local luac = require("luac")

local src = [[
local x = 10
if x > 5 then
    print("big")
elseif x > 2 then
    print("medium")
else
    print("small")
end
local i = 0
while i < 3 do
    print(i)
    i = i + 1
end
for j = 1, 3 do
    print(j)
end
print("done")
]]

-- 编译原始字节码
local f = load(src)
local orig_bc = string.dump(f, true)

-- 加载并应用cfg_shuffle
local h = luac.load(orig_bc)
luac.apply(h, "cfg_shuffle_c")
local new_bc = luac.dump(h)
luac.free(h)

-- 反汇编对比
local function disasm(bc, label)
    local p = luac.proto(bc)
    print("=== " .. label .. " ===")
    print("sizecode: " .. #p.code)
    local opcount = {}
    local jmpcount = 0
    for i, ins in ipairs(p.code) do
        local op = ins & 0x3F
        opcount[op] = (opcount[op] or 0) + 1
        if op == 30 then jmpcount = jmpcount + 1 end
    end
    print("JMP count: " .. jmpcount)
    print("Opcode distribution:")
    for op, cnt in pairs(opcount) do
        print(string.format("  op=%d: %d", op, cnt))
    end
    print()
    return #p.code, jmpcount
end

local orig_size, orig_jmp = disasm(orig_bc, "ORIGINAL")
local new_size, new_jmp = disasm(new_bc, "CFG_SHUFFLE")

print("=== SUMMARY ===")
print(string.format("Size: %d -> %d (%+d)", orig_size, new_size, new_size - orig_size))
print(string.format("JMP: %d -> %d (%+d)", orig_jmp, new_jmp, new_jmp - orig_jmp))
if new_size ~= orig_size or new_jmp ~= orig_jmp then
    print("PASS: Bytecode changed")
else
    print("FAIL: Bytecode unchanged")
end

-- 运行验证
print()
print("=== RUN VERIFICATION ===")
local f2 = load(new_bc)
f2()
print("Run OK")
