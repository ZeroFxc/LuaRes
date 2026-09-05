-- deobfuscate.lua - bytecode deobfuscator
-- Removes: illegal opcodes (OP_48 etc.), abnormal function headers,
--           optional debug info stripping
-- Usage: lua deobfuscate.lua <input.luac> <output.luac> [--strip]

local luac = require("luac")

local OP_EXTRAARG = luac.OP_EXTRAARG  -- 46, legal
local MAX_LEGAL_OP = 46  -- Lua 5.3 has opcodes 0-46

-- iAsBx opcodes needing sBx fixup
local ASBX_OPS = {
    [luac.OP_JMP] = true,
    [luac.OP_FORLOOP] = true,
    [luac.OP_FORPREP] = true,
    [luac.OP_TFORLOOP] = true,
}

-- Fix abnormal function header fields
local function fix_headers(p)
    -- numparams: normal 0-20, abnormal if > 100
    if p.numparams > 100 then
        p.numparams = 0
    end
    -- is_vararg: normal 0 or 1, abnormal if > 10
    if p.is_vararg > 10 then
        p.is_vararg = 0
    end
    -- maxstacksize: recalculate from actual register usage
    -- (leave as-is if reasonable, clamp if absurd)
    if p.maxstacksize > 200 then
        -- Recalculate: find max register used in instructions
        local max_reg = 2
        for i = 1, #p.code do
            local ins = p.code[i]
            local op = luac.GET_OPCODE(ins)
            local a = luac.GETARG_A(ins)
            if a > max_reg then max_reg = a end
            -- For iABC, check B and C if they are registers (< 0x100)
            if op ~= luac.OP_JMP and op ~= luac.OP_FORLOOP and op ~= luac.OP_FORPREP
               and op ~= luac.OP_TFORLOOP and op ~= luac.OP_LOADK and op ~= luac.OP_LOADKX
               and op ~= luac.OP_CLOSURE and op ~= OP_EXTRAARG then
                local b = luac.GETARG_B(ins)
                local c = luac.GETARG_C(ins)
                if b < 0x100 and b > max_reg then max_reg = b end
                if c < 0x100 and c > max_reg then max_reg = c end
            end
        end
        p.maxstacksize = max_reg + 1
    end
    for i = 1, #p.p do
        fix_headers(p.p[i])
    end
end

-- Remove illegal opcodes and fix jump offsets
local function remove_illegal_ops(p)
    local code = p.code
    local n = #code
    if n == 0 then return end

    -- First pass: mark which instructions to keep
    local keep = {}
    local has_illegal = false
    for i = 1, n do
        local op = luac.GET_OPCODE(code[i])
        if op <= MAX_LEGAL_OP then
            keep[i] = true
        else
            keep[i] = false
            has_illegal = true
        end
    end

    if not has_illegal then
        for i = 1, #p.p do remove_illegal_ops(p.p[i]) end
        return
    end

    -- Build position map: old_index -> new_index (1-based)
    local pos_map = {}
    local new_code = {}
    local new_pos = 0
    for i = 1, n do
        if keep[i] then
            new_pos = new_pos + 1
            pos_map[i] = new_pos
            table.insert(new_code, code[i])
        else
            pos_map[i] = nil  -- removed
        end
    end

    -- Fix jump offsets in kept instructions
    for i = 1, #new_code do
        local ins = new_code[i]
        local op = luac.GET_OPCODE(ins)
        if ASBX_OPS[op] then
            local old_sbx = luac.GETARG_sBx(ins)
            -- Find old index of this instruction
            local old_i = nil
            for oi, ni in pairs(pos_map) do
                if ni == i then old_i = oi; break end
            end
            if old_i then
                local old_target = old_i + old_sbx + 1
                if old_target >= 1 and old_target <= n and pos_map[old_target] then
                    local new_target = pos_map[old_target]
                    local new_sbx = new_target - i - 1
                    new_code[i] = luac.SETARG_sBx(ins, new_sbx)
                end
                -- If target was removed (jumped into dead code), leave as-is
                -- (the jump will now land at the next kept instruction)
            end
        end
    end

    p.code = new_code

    for i = 1, #p.p do
        remove_illegal_ops(p.p[i])
    end
end

-- Strip debug info
local function strip_debug(p)
    p.lineinfo = {}
    p.locvars = {}
    for i = 1, #p.upvalues do p.upvalues[i].name = "" end
    for i = 1, #p.p do strip_debug(p.p[i]) end
end

-- Main deobfuscate function
local function deobfuscate(data, options)
    options = options or {}
    local proto = luac.undump(data, false)

    local stats = {
        original_size = #data,
        headers_fixed = 0,
        illegal_removed = 0,
    }

    -- Count illegal ops before removal
    local function count_illegal(p)
        local count = 0
        for i = 1, #p.code do
            if luac.GET_OPCODE(p.code[i]) > MAX_LEGAL_OP then
                count = count + 1
            end
        end
        for i = 1, #p.p do count = count + count_illegal(p.p[i]) end
        return count
    end
    stats.illegal_removed = count_illegal(proto)

    -- 1. Fix abnormal headers
    fix_headers(proto)

    -- 2. Remove illegal opcodes
    remove_illegal_ops(proto)

    -- 3. Optional: strip debug info
    if options.strip then
        strip_debug(proto)
    end

    local out = luac.dump(proto)
    stats.clean_size = #out
    stats.ratio = string.format("%.1f%%", (#out / #data) * 100)
    return out, stats
end

-- CLI
if arg and arg[0] and arg[0]:match("deobfuscate") and arg[1] and arg[2] then
    local input_path = arg[1]
    local output_path = arg[2]
    local options = {}
    for i = 3, #arg do
        if arg[i] == "--strip" then options.strip = true end
    end

    local f = io.open(input_path, "rb")
    if not f then print("cannot open " .. input_path); os.exit(1) end
    local data = f:read("*a")
    f:close()

    print("Deobfuscating: " .. input_path)
    print("Original size: " .. #data .. " bytes")

    local out, stats = deobfuscate(data, options)

    f = io.open(output_path, "wb")
    f:write(out)
    f:close()

    print(string.format("Clean size: %d bytes (%s)", stats.clean_size, stats.ratio))
    print(string.format("Illegal opcodes removed: %d", stats.illegal_removed))
    if options.strip then print("Debug info stripped") end

    local ok, func = pcall(load, out)
    if ok and func then
        print("[PASS] Cleaned bytecode loads successfully")
    else
        print("[FAIL] Load failed: " .. tostring(func))
    end
    print("Output: " .. output_path)
end

return {
    deobfuscate = deobfuscate,
    fix_headers = fix_headers,
    remove_illegal_ops = remove_illegal_ops,
    strip_debug = strip_debug,
}
