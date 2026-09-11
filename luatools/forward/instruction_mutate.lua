-- instruction_mutate.lua - mutate instruction encodings using algebraic identities
--   1. Commutative operand swap: ADD/MUL/EQ/AND/OR/XOR have B,C swapped randomly
--   2. Arithmetic identity insertion: insert "ADD A A, Kst(0)" after numeric ops
--      (with jump offset correction)
--
-- Usage: lua instruction_mutate.lua <input.luac> <output.luac>
local luac = require("luac")

local BITRK = 0x100

-- Opcodes where B and C are commutative (swapping doesn't change semantics)
local COMMUTATIVE = {
    [luac.OP_ADD] = true,
    [luac.OP_MUL] = true,
    [luac.OP_EQ] = true,
    [luac.OP_BAND] = true,
    [luac.OP_BOR] = true,
    [luac.OP_BXOR] = true,
}

-- Opcodes that produce a numeric result in register A (can append identity ADD A,A,0)
-- Excludes LOADK/LOADKX because they may load non-numeric constants
local NUMERIC_RESULT = {
    [luac.OP_ADD] = true,
    [luac.OP_SUB] = true,
    [luac.OP_MUL] = true,
    [luac.OP_DIV] = true,
    [luac.OP_IDIV] = true,
    [luac.OP_MOD] = true,
    [luac.OP_POW] = true,
    [luac.OP_UNM] = true,
    [luac.OP_BNOT] = true,
    [luac.OP_BAND] = true,
    [luac.OP_BOR] = true,
    [luac.OP_BXOR] = true,
    [luac.OP_SHL] = true,
    [luac.OP_SHR] = true,
    [luac.OP_LEN] = true,
}

-- Jump opcodes (iAsBx format) whose sBx needs correction after insertion
local JUMP_OPS = {
    [luac.OP_JMP] = true,
    [luac.OP_FORLOOP] = true,
    [luac.OP_FORPREP] = true,
    [luac.OP_TFORLOOP] = true,
}

-- Find or add integer constant 0, return its index
local function get_zero_const(proto)
    for i = 1, #proto.k do
        if proto.k[i] == 0 and type(proto.k[i]) == "number" then
            return i - 1
        end
    end
    table.insert(proto.k, 0)
    return #proto.k - 1
end

local function mutate_function(proto)
    local zero_idx = get_zero_const(proto)
    local code = proto.code
    local n = #code

    -- Build new code with insertions, track position mapping
    local new_code = {}
    -- pos_map[old_index] = new_index (1-based)
    local pos_map = {}
    local inserted_before = 0

    for i = 1, n do
        local ins = code[i]
        local op = luac.GET_OPCODE(ins)

        pos_map[i] = #new_code + 1

        -- 1. Commutative operand swap (50% chance)
        if COMMUTATIVE[op] and math.random() < 0.5 then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            ins = luac.SETARG_B(ins, c)
            ins = luac.SETARG_C(ins, b)
        end

        table.insert(new_code, ins)

        -- 2. Insert identity ADD A,A,Kst(0) after numeric result ops (25% chance)
        if NUMERIC_RESULT[op] and math.random() < 0.25 then
            local a = luac.GETARG_A(ins)
            if a < proto.maxstacksize then
                local identity = luac.CREATE_ABC(luac.OP_ADD, a, a, zero_idx + BITRK)
                table.insert(new_code, identity)
                inserted_before = inserted_before + 1
            end
        end
    end

    -- Correct jump offsets: for each jump in new_code, find its original index
    -- and compute corrected sBx based on new positions.
    -- We need to map new_code index back to original code index.
    -- Build reverse map: for each new_code entry, store original index (or nil for inserted).
    local rev_map = {}
    local orig_idx = 0
    for i = 1, #new_code do
        -- Check if this position corresponds to an original instruction
        -- by checking pos_map
        local found = false
        for j = 1, n do
            if pos_map[j] == i then
                rev_map[i] = j
                found = true
                break
            end
        end
        if not found then
            rev_map[i] = nil  -- inserted instruction
        end
    end

    -- Correct jumps
    for i = 1, #new_code do
        local ins = new_code[i]
        local op = luac.GET_OPCODE(ins)
        if JUMP_OPS[op] then
            local old_sbx = luac.GETARG_sBx(ins)
            -- Original jump was at some original index; find it
            local orig_i = rev_map[i]
            if orig_i then
                -- Original target = orig_i + old_sbx + 1 (1-based)
                local orig_target = orig_i + old_sbx + 1
                if orig_target >= 1 and orig_target <= n then
                    local new_target = pos_map[orig_target]
                    if new_target then
                        local new_sbx = new_target - i - 1
                        new_code[i] = luac.SETARG_sBx(ins, new_sbx)
                    end
                end
            end
        end
    end

    proto.code = new_code
end

local function process_function(proto)
    mutate_function(proto)
    for i = 1, #proto.p do
        mutate_function(proto.p[i])
    end
end

local function process(input_path, output_path)
    local f = io.open(input_path, "rb")
    if not f then error("cannot open " .. input_path) end
    local data = f:read("*a")
    f:close()

    if data:byte(1) == string.byte('=') then
        data = string.dec(data)
    end

    local proto = luac.undump(data, true)
    print(string.format("Loaded: sizecode=%d sizek=%d", proto.sizecode, proto.sizek))

    math.randomseed(os.time())
    process_function(proto)

    local out = luac.dump(proto)
    f = io.open(output_path, "wb")
    f:write(out)
    f:close()
    print(string.format("Mutated: %d bytes (was %d), new sizecode=%d", #out, #data, #proto.code))

    local func = load(out)
    if func then
        print("Verification: bytecode loads OK")
    else
        print("WARNING: bytecode failed to load!")
    end
end

if arg and arg[0] and arg[0]:match("instruction_mutate") and arg[1] and arg[2] then
    process(arg[1], arg[2])
end

return {
    mutate_function = mutate_function,
    process_function = process_function,
    process = process,
}
