-- const_shuffle.lua - shuffle constant pool and fix all instruction references
-- Usage: lua const_shuffle.lua <input.luac> <output.luac>
local luac = require("luac")

local BITRK = 0x100
local OP_LOADK = luac.OP_LOADK
local OP_LOADKX = luac.OP_LOADKX
local OP_EXTRAARG = luac.OP_EXTRAARG
local OP_CLOSURE = luac.OP_CLOSURE

-- Generate a random permutation of 0..n-1
local function rand_perm(n)
    local perm = {}
    for i = 0, n - 1 do perm[i + 1] = i end
    -- Fisher-Yates shuffle
    for i = n, 2, -1 do
        local j = math.random(i)
        perm[i], perm[j] = perm[j], perm[i]
    end
    return perm
end

-- Build inverse mapping: old_index -> new_index
local function build_remap(perm)
    local remap = {}
    for new_idx, old_idx in ipairs(perm) do
        remap[old_idx] = new_idx - 1  -- 0-based
    end
    return remap
end

local function shuffle_function(proto)
    local n = #proto.k  -- use table length, not proto.sizek (may be stale)
    if n <= 1 then
        for i = 1, proto.sizep do shuffle_function(proto.p[i]) end
        return
    end

    local perm = rand_perm(n)
    local remap = build_remap(perm)

    -- Rebuild constant table in new order
    local old_k = {}
    for i = 1, n do old_k[i] = proto.k[i] end
    for new_idx, old_idx in ipairs(perm) do
        proto.k[new_idx] = old_k[old_idx + 1]
    end

    -- Fix all instruction references
    local code = proto.code
    for i = 1, #code do
        local ins = code[i]
        local op = luac.GET_OPCODE(ins)

        if op == OP_LOADK or op == OP_LOADKX then
            -- iABx: Bx is constant index (NOT closure index)
            local old_bx = luac.GETARG_Bx(ins)
            if remap[old_bx] then
                code[i] = luac.SETARG_Bx(ins, remap[old_bx])
            end
        elseif op == OP_EXTRAARG then
            -- iAx: Ax is constant index
            local old_ax = luac.GETARG_Ax(ins)
            if remap[old_ax] then
                code[i] = luac.SETARG_Ax(ins, remap[old_ax])
            end
        elseif op ~= OP_CLOSURE and op ~= luac.OP_JMP and op ~= luac.OP_FORLOOP
               and op ~= luac.OP_FORPREP and op ~= luac.OP_TFORLOOP then
            -- iABC: check B and C for constant references (BITRK set)
            -- Exclude iAsBx opcodes (JMP/FORLOOP/FORPREP/TFORLOOP) whose sBx
            -- occupies B+C bitfields and must not be interpreted as constant refs.
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            local changed = false
            if b >= BITRK then
                local old_idx = b - BITRK
                if remap[old_idx] then
                    b = remap[old_idx] + BITRK
                    changed = true
                end
            end
            if c >= BITRK then
                local old_idx = c - BITRK
                if remap[old_idx] then
                    c = remap[old_idx] + BITRK
                    changed = true
                end
            end
            if changed then
                code[i] = luac.SETARG_B(ins, b)
                code[i] = luac.SETARG_C(code[i], c)
            end
        end
        -- OP_CLOSURE: Bx is proto index, leave alone
    end

    -- Recurse into sub-functions
    for i = 1, proto.sizep do
        shuffle_function(proto.p[i])
    end
end

local function shuffle(input, output)
    -- 支持直接传入 luac.Proto
    if type(input) == 'userdata' then
        math.randomseed(os.time())
        shuffle_function(input)
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
    print(string.format("Loaded: sizecode=%d sizek=%d sizep=%d",
        proto.sizecode, proto.sizek, proto.sizep))

    math.randomseed(os.time())
    shuffle_function(proto)

    local out = luac.dump(proto)
    f = io.open(output_path, "wb")
    f:write(out)
    f:close()
    print(string.format("Shuffled: %d bytes", #out))

    local func = load(out)
    if func then
        print("Verification: bytecode loads OK")
    else
        print("WARNING: bytecode failed to load!")
    end
end

if arg and arg[0] and arg[0]:match("const_shuffle") and arg[1] and arg[2] then
    shuffle(arg[1], arg[2])
end

return {
    shuffle_function = shuffle_function,
    shuffle = shuffle,
}
