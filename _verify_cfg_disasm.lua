-- 反汇编字节码文件并统计opcode
local luac = require("luac")

local function analyze(bc_path, label)
    local f = io.open(bc_path, "rb")
    local bc = f:read("*a")
    f:close()

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
    local sorted = {}
    for op, cnt in pairs(opcount) do
        table.insert(sorted, {op=op, cnt=cnt})
    end
    table.sort(sorted, function(a,b) return a.op < b.op end)
    for _, item in ipairs(sorted) do
        print(string.format("  op=%2d: %d", item.op, item.cnt))
    end
    print()
    return #p.code, jmpcount
end

local orig_size, orig_jmp = analyze("_cfg_verify_orig.luac", "ORIGINAL")
local new_size, new_jmp = analyze("_cfg_verify_after.luac", "CFG_SHUFFLE")

print("=== SUMMARY ===")
print(string.format("Size: %d -> %d (%+d)", orig_size, new_size, new_size - orig_size))
print(string.format("JMP:  %d -> %d (%+d)", orig_jmp, new_jmp, new_jmp - orig_jmp))
if new_size ~= orig_size or new_jmp ~= orig_jmp then
    print("PASS: Bytecode changed")
else
    print("FAIL: Bytecode unchanged")
end
