-- luac_flatten.lua - Control Flow Flattening pass for luac library
-- Converts linear control flow into a state-machine dispatch loop
local luac = require("luac")

--===========================================================================
-- Basic Block identification
--===========================================================================

-- Opcodes that end a basic block unconditionally
local UNCOND_END = {
    [luac.OP_JMP] = true,
    [luac.OP_RETURN] = true,
    [luac.OP_TAILCALL] = true,
}

-- Opcodes that are conditional (fall through + implicit skip-next)
local COND_OPS = {
    [luac.OP_EQ] = true,
    [luac.OP_LT] = true,
    [luac.OP_LE] = true,
    [luac.OP_TEST] = true,
    [luac.OP_TESTSET] = true,
}

-- Loop-related opcodes (blocks containing these are kept as-is)
local LOOP_OPS = {
    [luac.OP_FORLOOP] = true,
    [luac.OP_FORPREP] = true,
    [luac.OP_TFORLOOP] = true,
    [luac.OP_TFORCALL] = true,
}

local function is_jump_target(op)
    return op == luac.OP_JMP or op == luac.OP_FORLOOP
        or op == luac.OP_FORPREP or op == luac.OP_TFORLOOP
end

-- Identify basic blocks. Returns array of {start, stop, id, kind}
-- kind: "normal", "loop", "exit"
local function identify_blocks(code, n)
    local is_start = {}
    is_start[1] = true

    for i = 1, n do
        local op = luac.GET_OPCODE(code[i])
        -- Only unconditional jumps/returns end a block
        -- Conditional ops (EQ/LT/LE/TEST/TESTSET) stay with their following JMP
        if UNCOND_END[op] or LOOP_OPS[op] then
            if i + 1 <= n then is_start[i + 1] = true end
            if is_jump_target(op) then
                local sbx = luac.GETARG_sBx(code[i])
                local target = i + sbx + 1
                if target >= 1 and target <= n then
                    is_start[target] = true
                end
            end
        end
    end

    local blocks = {}
    local cur = 1
    for i = 1, n do
        if is_start[i] and i > cur then
            table.insert(blocks, {start = cur, stop = i - 1})
            cur = i
        end
    end
    table.insert(blocks, {start = cur, stop = n})

    for idx, b in ipairs(blocks) do
        b.id = idx - 1
        b.kind = "normal"
        for i = b.start, b.stop do
            local op = luac.GET_OPCODE(code[i])
            if LOOP_OPS[op] then b.kind = "loop"; break end
            if op == luac.OP_RETURN or op == luac.OP_TAILCALL then
                b.kind = "exit"
            end
        end
    end

    return blocks
end

-- Find block ID by instruction position
local function block_id_at(blocks, pos)
    for _, b in ipairs(blocks) do
        if pos >= b.start and pos <= b.stop then return b.id end
    end
    return -1
end

--===========================================================================
-- Constant pool helpers
--===========================================================================

-- Find or add an integer constant, returns index (0-based)
local function get_int_const(proto, val)
    for i = 1, #proto.k do
        if proto.k[i] == val and type(proto.k[i]) == "number" then
            return i - 1
        end
    end
    table.insert(proto.k, val)
    return #proto.k - 1
end

--===========================================================================
-- Flatten one function
--===========================================================================

local function flatten_function(proto)
    local code = proto.code
    local n = proto.sizecode
    if n <= 3 then return end  -- too small to flatten

    local blocks = identify_blocks(code, n)
    if #blocks <= 2 then return end  -- not enough blocks

    -- Check if there are loop blocks; if so, skip flattening this function
    -- (loop structures are too complex to flatten safely)
    for _, b in ipairs(blocks) do
        if b.kind == "loop" then return end
    end

    local state_reg = proto.maxstacksize  -- use register beyond current max
    local dispatcher_id = #blocks  -- virtual block ID for dispatcher

    -- Build new code
    local new_code = {}

    -- Helper to append instruction
    local function emit(ins)
        table.insert(new_code, ins)
    end

    -- Phase 1: Build dispatch table (will fixup offsets later)
    -- We need to know where each block starts in new_code
    local block_offsets = {}  -- block_id -> position in new_code (1-based)
    local dispatcher_start = 0

    -- First, emit the initial state load + dispatcher
    -- LOADK state_reg, Kst(first_block_id)
    local first_k = get_int_const(proto, blocks[1].id)
    emit(luac.CREATE_ABx(luac.OP_LOADK, state_reg, first_k))

    -- Dispatcher start marker
    dispatcher_start = #new_code + 1

    -- For each block, emit: EQ state_reg, Kst(block_id), 0; JMP to_block
    -- We'll fixup JMP offsets after we know block positions
    local dispatch_jmp_pos = {}  -- block_id -> position of JMP instruction in new_code

    for _, b in ipairs(blocks) do
        local kid = get_int_const(proto, b.id)
        -- EQ 1 R(state_reg) Kst(kid)  -- if state ~= block_id, skip next (jump only when equal)
        emit(luac.CREATE_ABC(luac.OP_EQ, 1, state_reg, kid + 0x100))
        -- JMP to_block (offset to be fixed)
        dispatch_jmp_pos[b.id] = #new_code + 1
        emit(0)  -- placeholder JMP
    end

    -- If no block matched (shouldn't happen), just continue
    -- (fall through to first block is fine, or we could emit RETURN)

    -- Phase 2: Emit each block's instructions, with control flow conversion
    for _, b in ipairs(blocks) do
        block_offsets[b.id] = #new_code + 1

        for i = b.start, b.stop do
            local ins = code[i]
            local op = luac.GET_OPCODE(ins)

            if op == luac.OP_JMP then
                -- Unconditional jump: convert to state load + jump to dispatcher
                local sbx = luac.GETARG_sBx(ins)
                local target_pos = i + sbx + 1
                local target_id = block_id_at(blocks, target_pos)
                if target_id >= 0 then
                    local kid = get_int_const(proto, target_id)
                    emit(luac.CREATE_ABx(luac.OP_LOADK, state_reg, kid))
                else
                    -- Unknown target, keep original jump (shouldn't happen)
                    emit(ins)
                end
                -- JMP to dispatcher (offset fixed later)
                emit(0xDEAD)  -- placeholder, will fix
            elseif COND_OPS[op] then
                -- Conditional jump pattern: COND A B C; JMP sBx
                -- condition true -> skip JMP -> fall through to then-branch
                -- condition false -> execute JMP -> jump to else-branch
                if i + 1 <= b.stop and luac.GET_OPCODE(code[i + 1]) == luac.OP_JMP then
                    local jmp_ins = code[i + 1]
                    local jmp_sbx = luac.GETARG_sBx(jmp_ins)
                    local else_pos = i + 1 + jmp_sbx + 1
                    local else_id = block_id_at(blocks, else_pos)
                    local then_id = block_id_at(blocks, i + 2)

                    -- Emit condition instruction
                    emit(ins)

                    -- JMP to else-state (skipped if condition true)
                    local jmp_to_else_pos = #new_code + 1
                    emit(0xBEEF)  -- placeholder

                    -- condition true (skip JMP): set state = then_id
                    if then_id >= 0 then
                        local kid = get_int_const(proto, then_id)
                        emit(luac.CREATE_ABx(luac.OP_LOADK, state_reg, kid))
                    end
                    emit(0xDEAD)  -- JMP to dispatcher

                    -- condition false (jump here): set state = else_id
                    local else_state_pos = #new_code + 1
                    if else_id >= 0 then
                        local kid = get_int_const(proto, else_id)
                        emit(luac.CREATE_ABx(luac.OP_LOADK, state_reg, kid))
                    end
                    emit(0xDEAD)  -- JMP to dispatcher

                    -- Fixup JMP to else-state
                    local sbx = else_state_pos - jmp_to_else_pos - 1
                    new_code[jmp_to_else_pos] = luac.CREATE_AsBx(luac.OP_JMP, 0, sbx)

                    i = i + 1  -- skip original JMP
                else
                    emit(ins)
                end
            elseif op == luac.OP_RETURN or op == luac.OP_TAILCALL then
                -- Exit block: keep as-is
                emit(ins)
            else
                -- Normal instruction: keep as-is
                emit(ins)
            end
        end

        -- If block ends with a fall-through (not JMP/RETURN/COND),
        -- add state load for next block + jump to dispatcher
        local last_op = luac.GET_OPCODE(code[b.stop])
        if not (UNCOND_END[last_op] or COND_OPS[last_op]) then
            local next_id = block_id_at(blocks, b.stop + 1)
            if next_id >= 0 then
                local kid = get_int_const(proto, next_id)
                emit(luac.CREATE_ABx(luac.OP_LOADK, state_reg, kid))
                emit(0xDEAD)  -- JMP to dispatcher placeholder
            end
        end
    end

    -- Phase 3: Fixup all placeholder JMPs and dispatch JMPs
    -- First, fix dispatch table JMPs
    for bid, pos in pairs(dispatch_jmp_pos) do
        local target = block_offsets[bid]
        if target then
            local sbx = target - pos - 1
            new_code[pos] = luac.CREATE_AsBx(luac.OP_JMP, 0, sbx)
        end
    end

    -- Fix 0xDEAD placeholders (jump to dispatcher)
    for i, ins in ipairs(new_code) do
        if ins == 0xDEAD then
            local sbx = dispatcher_start - i - 1
            new_code[i] = luac.CREATE_AsBx(luac.OP_JMP, 0, sbx)
        end
    end

    -- Update proto
    proto.code = new_code
    proto.sizecode = #new_code
    proto.maxstacksize = state_reg + 1  -- +1 for state register
end

-- Recursively flatten all functions
local function flatten_proto(proto)
    flatten_function(proto)
    for i = 1, proto.sizep do
        flatten_proto(proto.p[i])
    end
end

--===========================================================================
-- Main
--===========================================================================

local function flatten(input_path, output_path)
    local f = io.open(input_path, "rb")
    if not f then error("cannot open " .. input_path) end
    local data = f:read("*a")
    f:close()

    if data:byte(1) == string.byte('=') then
        data = string.dec(data)
    end

    local proto = luac.undump(data, true)
    print(string.format("Loaded: sizecode=%d sizek=%d sizep=%d maxstack=%d",
        proto.sizecode, proto.sizek, proto.sizep, proto.maxstacksize))

    flatten_proto(proto)
    print(string.format("Flattened: sizecode=%d sizek=%d maxstack=%d",
        proto.sizecode, proto.sizek, proto.maxstacksize))

    local out = luac.dump(proto)

    f = io.open(output_path, "wb")
    f:write(out)
    f:close()
    print(string.format("Written %d bytes to %s", #out, output_path))

    local func = load(out)
    if func then
        print("Verification: bytecode loads OK")
    else
        print("WARNING: bytecode failed to load!")
    end
end

if arg[1] and arg[2] then
    flatten(arg[1], arg[2])
else
    print("Usage: lua luac_flatten.lua <input.luac> <output.luac>")
end
