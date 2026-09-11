-- opaque_predicate.lua - insert opaque predicates with dead code blocks
-- An opaque predicate is a condition that is always true/false but looks
-- like a real branch. Dead code behind the false branch is never executed.
--
-- Usage: lua opaque_predicate.lua <input.luac> <output.luac>
local luac = require("luac")

local BITRK = 0x100

-- Generate a random instruction (valid-ish but harmless)
local function random_insn()
    local op = math.random(0, 45)  -- exclude 46 (EXTRAARG, requires LOADKX prefix + iAx format)
    local a = math.random(0, 15)
    local b = math.random(0, 15)
    local c = math.random(0, 15)
    -- Avoid RETURN/CALL in dead code (could accidentally affect stack)
    if op == luac.OP_RETURN or op == luac.OP_CALL or op == luac.OP_TAILCALL then
        op = luac.OP_MOVE
    end
    -- Avoid LOADKX (requires following EXTRAARG) and SETLIST with C=0 (requires EXTRAARG)
    if op == luac.OP_LOADKX then
        op = luac.OP_LOADK
    end
    if op == luac.OP_JMP then
        return luac.CREATE_AsBx(luac.OP_JMP, 0, math.random(1, 5))
    elseif op == luac.OP_LOADK then
        return luac.CREATE_ABx(luac.OP_LOADK, a, math.random(0, 5))
    else
        if op == luac.OP_SETLIST then
            c = math.random(1, 15)  -- avoid C=0 which requires following EXTRAARG
        end
        return luac.CREATE_ABC(op, a, b, c)
    end
end

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

local function add_opaque_block(proto)
    local n = #proto.code  -- use table length, not proto.sizecode (may be stale)
    if n <= 2 then return end

    local zero_idx = get_zero_const(proto)
    local r1 = proto.maxstacksize
    local r2 = proto.maxstacksize + 1
    local dead_len = math.random(5, 15)

    local new_code = {}
    table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, r1, zero_idx))
    table.insert(new_code, luac.CREATE_ABx(luac.OP_LOADK, r2, zero_idx))
    -- LT 0: A=0 means skip if (B<C) ~= false. 0<0 is false, so never skip.
    table.insert(new_code, luac.CREATE_ABC(luac.OP_LT, 0, r1, r2))
    -- JMP at index 4 (1-based), sBx = dead_len
    table.insert(new_code, luac.CREATE_AsBx(luac.OP_JMP, 0, dead_len))

    -- Dead code
    for i = 1, dead_len do
        table.insert(new_code, random_insn())
    end

    -- Original code
    local old_code = proto.code
    for i = 1, n do
        table.insert(new_code, old_code[i])
    end

    proto.code = new_code
    proto.maxstacksize = r2 + 1
end

local function process_function(proto)
    add_opaque_block(proto)
    -- Also add to sub-functions (but not too deep to avoid bloat)
    for i = 1, #proto.p do
        if proto.p[i].sizecode > 4 then
            add_opaque_block(proto.p[i])
        end
    end
end

local function process(input, output)
    if type(input) == 'userdata' then
        math.randomseed(os.time())
        process_function(input)
        return
    end
    local f = io.open(input, "rb")
    if not f then error("cannot open " .. input) end
    local data = f:read("*a")
    f:close()

    if data:byte(1) == string.byte('=') then
        data = string.dec(data)
    end

    local proto = luac.undump(data, true)
    print(string.format("Loaded: sizecode=%d sizek=%d sizep=%d maxstack=%d",
        proto.sizecode, proto.sizek, proto.sizep, proto.maxstacksize))

    math.randomseed(os.time())
    process_function(proto)

    local out = luac.dump(proto)
    f = io.open(output_path, "wb")
    f:write(out)
    f:close()
    print(string.format("Opaque: %d bytes (was %d), new sizecode=%d", #out, #data, #proto.code))

    local func = load(out)
    if func then
        print("Verification: bytecode loads OK")
    else
        print("WARNING: bytecode failed to load!")
    end
end

if arg and arg[0] and arg[0]:match("opaque_predicate") and arg[1] and arg[2] then
    process(arg[1], arg[2])
end

return {
    process_function = process_function,
    add_opaque_block = add_opaque_block,
    process = process,
}
