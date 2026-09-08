local luac = require("luac")

local function disasm(bc_path, label)
    local f = io.open(bc_path, "rb")
    local bc = f:read("*a")
    f:close()

    local p = luac.undump(bc)
    -- p is the main proto; p.code is the instruction array
    print("=== " .. label .. " ===")
    print("sizecode: " .. #p.code)
    local opcount = {}
    local jmpcount = 0
    for i = 1, #p.code do
        local ins = p.code[i]
        local op = luac.GET_OPCODE(ins)
        opcount[op] = (opcount[op] or 0) + 1
        if op == luac.OP_JMP then jmpcount = jmpcount + 1 end
        local a = luac.GETARG_A(ins)
        local name = luac.OPCODE_NAMES[op] or ("op"..op)
        if op == luac.OP_JMP or op == luac.OP_FORLOOP or op == luac.OP_FORPREP or op == luac.OP_TFORLOOP then
            local sbx = luac.GETARG_sBx(ins)
            local target = i + sbx  -- i is 1-based, pc+1 = i, target = i + sbx
            print(string.format("  [%02d] %-12s A=%d sbx=%d -> %d", i-1, name, a, sbx, target-1))
        else
            print(string.format("  [%02d] %-12s A=%d", i-1, name, a))
        end
    end
    print()
    print("JMP count: " .. jmpcount)
    print("Opcode distribution:")
    local sorted = {}
    for op, cnt in pairs(opcount) do
        table.insert(sorted, {op=op, name=luac.OPCODE_NAMES[op] or ("op"..op), cnt=cnt})
    end
    table.sort(sorted, function(a,b) return a.op < b.op end)
    for _, item in ipairs(sorted) do
        print(string.format("  op=%2d %-12s: %d", item.op, item.name, item.cnt))
    end
    print()
    return #p.code, jmpcount
end

local orig_size, orig_jmp = disasm("_cfg_verify_orig.luac", "ORIGINAL")
local new_size, new_jmp = disasm("_cfg_verify_after.luac", "CFG_SHUFFLE")

print("=== SUMMARY ===")
print(string.format("Size: %d -> %d (%+d)", orig_size, new_size, new_size - orig_size))
print(string.format("JMP:  %d -> %d (%+d)", orig_jmp, new_jmp, new_jmp - orig_jmp))
if new_size ~= orig_size or new_jmp ~= orig_jmp then
    print("PASS: Bytecode opcode changed")
else
    print("FAIL: Bytecode opcode unchanged")
end
