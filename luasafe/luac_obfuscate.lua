-- luac_obfuscate.lua - bytecode obfuscator using luac library
-- Equivalent to com.nwdxlgzs.luac53support Java tool
local luac = require("luac")

-- Logical opcodes (need extra JMP)
local LOGICAL_OPS = {
    [luac.OP_LOADBOOL] = true,
    [luac.OP_EQ] = true,
    [luac.OP_LT] = true,
    [luac.OP_LE] = true,
    [luac.OP_TEST] = true,
    [luac.OP_TESTSET] = true,
}

-- iAsBx opcodes (need sBx fixup)
local ASBX_OPS = {
    [luac.OP_JMP] = true,
    [luac.OP_FORLOOP] = true,
    [luac.OP_FORPREP] = true,
}

local function make_jmp(sbx)
    return luac.CREATE_AsBx(luac.OP_JMP, 0, sbx)
end

local function random_inst()
    return math.random(0, 0x1099FFFFF)
end

-- Obfuscate one function's code
local function handle_code(proto)
    local code = proto.code
    local n = proto.sizecode
    local groups = {}  -- each original instruction -> group of instructions

    for i = 1, n do
        local inst = code[i]
        local op = luac.GET_OPCODE(inst)
        local group = {inst}

        if op == luac.OP_TFORCALL then
            -- TFORCALL: no garbage
            groups[i] = group
        else
            local brush = math.random(5, 20)
            local logical = LOGICAL_OPS[op] ~= nil

            -- JMP to skip garbage
            table.insert(group, make_jmp(brush + 1))

            if logical then
                -- logical: extra JMP
                table.insert(group, make_jmp(brush + 1))
            else
                -- non-logical: one random instruction
                table.insert(group, random_inst())
            end

            -- brush random garbage instructions
            for j = 1, brush do
                table.insert(group, random_inst())
            end

            groups[i] = group
        end
    end

    -- Compute position of each original instruction in new code
    local orig_pos = {}
    local pos = 0
    for i = 1, n do
        orig_pos[i] = pos
        pos = pos + #groups[i]
    end

    -- Fixup iAsBx instructions
    for i = 1, n do
        local inst = groups[i][1]
        local op = luac.GET_OPCODE(inst)
        if ASBX_OPS[op] then
            local old_sbx = luac.GETARG_sBx(inst)
            local target_idx = i + old_sbx + 1
            if target_idx >= 1 and target_idx <= n then
                local new_target_pos = orig_pos[target_idx]
                local new_current_pos = orig_pos[i]
                local new_sbx = new_target_pos - new_current_pos - 1
                groups[i][1] = luac.SETARG_sBx(inst, new_sbx)
            end
        end
    end

    -- Flatten groups into new code
    local new_code = {}
    for i = 1, n do
        for j = 1, #groups[i] do
            table.insert(new_code, groups[i][j])
        end
    end

    proto.code = new_code
    proto.sizecode = #new_code
end

-- Recursively obfuscate all functions
local function obfuscate_proto(proto)
    handle_code(proto)
    for i = 1, proto.sizep do
        obfuscate_proto(proto.p[i])
    end
end

-- Main
local function obfuscate(input_path, output_path)
    -- Read and decrypt andlua bytecode
    local f = io.open(input_path, "rb")
    if not f then error("cannot open " .. input_path) end
    local data = f:read("*a")
    f:close()

    -- If starts with '=', it's andlua base64 shell -> decrypt first
    if data:byte(1) == string.byte('=') then
        data = string.dec(data)
    end

    -- undump (encrypted=true for andlua string encryption)
    local proto = luac.undump(data, true)
    print(string.format("Loaded: sizecode=%d sizek=%d sizep=%d",
        proto.sizecode, proto.sizek, proto.sizep))

    -- Obfuscate
    obfuscate_proto(proto)
    print(string.format("Obfuscated: sizecode=%d", proto.sizecode))

    -- Dump
    local out = luac.dump(proto)

    -- Write
    f = io.open(output_path, "wb")
    f:write(out)
    f:close()
    print(string.format("Written %d bytes to %s", #out, output_path))

    -- Verify: load and run
    local func = load(out)
    if func then
        print("Verification: bytecode loads OK")
    else
        print("WARNING: bytecode failed to load!")
    end
end

-- CLI
if arg[1] and arg[2] then
    obfuscate(arg[1], arg[2])
else
    print("Usage: lua luac_obfuscate.lua <input.luac> <output.luac>")
end
