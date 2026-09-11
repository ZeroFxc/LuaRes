-- proto_shuffle.lua - shuffle child proto order and fix CLOSURE Bx indices
local luac = require("luac")

local OP_CLOSURE = luac.OP_CLOSURE

local function shuffle_function(proto)
    local n = #proto.p
    if n < 2 then
        for i = 1, n do
            if proto.p[i] then shuffle_function(proto.p[i]) end
        end
        return 0
    end

    -- deterministic permutation: even indices first, then odd (0-based)
    local order = {}
    local idx = 1
    for i = 0, n - 1, 2 do order[idx] = i + 1; idx = idx + 1 end
    for i = 1, n - 1, 2 do order[idx] = i + 1; idx = idx + 1 end

    -- map[old_index_1based] = new_index_1based
    local map = {}
    for new_i = 1, n do
        map[order[new_i]] = new_i
    end

    -- reorder proto.p
    local old_p = {}
    for i = 1, n do old_p[i] = proto.p[i] end
    for new_i = 1, n do
        proto.p[new_i] = old_p[order[new_i]]
    end

    -- fix all CLOSURE instructions: Bx = old sub-proto index (0-based) -> new index
    local count = 0
    local code = proto.code
    for i = 1, #code do
        local ins = code[i]
        if luac.GET_OPCODE(ins) == OP_CLOSURE then
            local old_bx = luac.GETARG_Bx(ins)  -- 0-based
            if old_bx >= 0 and old_bx < n then
                local new_bx = map[old_bx + 1] - 1  -- to 0-based
                code[i] = luac.SETARG_Bx(ins, new_bx)
                count = count + 1
            end
        end
    end

    -- recurse
    for i = 1, n do
        if proto.p[i] then count = count + shuffle_function(proto.p[i]) end
    end
    return count
end

local function shuffle(proto)
    if type(proto) ~= 'userdata' then error("proto_shuffle: expected proto userdata") end
    return shuffle_function(proto)
end

return {
    shuffle_function = shuffle_function,
    shuffle = shuffle,
}
