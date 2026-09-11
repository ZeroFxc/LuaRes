-- live_range_split.lua - split register live ranges
-- Saves a register's value to a high register, overwrites with dummy, restores.
local luac = require("luac")

local OP_LOADK = luac.OP_LOADK
local OP_MOVE = luac.OP_MOVE
local JUMP_OPS = {[30]=true,[39]=true,[40]=true,[42]=true}

-- adjust jumps after inserting n instructions at insert_pos (1-based)
local function adjust_jumps(code, insert_pos, n)
    for i = 1, #code do
        local op = code[i] % 64
        if JUMP_OPS[op] then
            local bx = code[i] >> 14
            local sbx = bx - 131071
            local target = i + sbx + 1
            local delta = 0
            if i < insert_pos and target >= insert_pos then
                delta = n
            elseif i >= insert_pos and target < insert_pos then
                delta = -n
            end
            if delta ~= 0 then
                local new_sbx = sbx + delta
                local new_bx = new_sbx + 131071
                code[i] = (code[i] & 0x3FFF) | (new_bx << 14)
            end
        end
    end
end

-- make MOVE dst, src
local function make_move(dst, src)
    return (OP_MOVE) | (dst << 6) | (src << 23)
end

-- make LOADK dst, kidx
local function make_loadk(dst, kidx)
    return (OP_LOADK) | (dst << 6) | (kidx << 14)
end

local function split_function(proto)
    if not proto.code or #proto.code < 4 then return 0 end
    if proto.is_vararg and proto.is_vararg ~= 0 then return 0 end

    local old_max = proto.maxstacksize or 0
    if old_max + 1 > 250 then return 0 end
    local high_reg = old_max

    -- add zero constant
    local zero_kidx = #proto.k
    proto.k[zero_kidx + 1] = 0.0

    -- find all LOADK positions with target register < old_max
    local positions = {}
    for i = 1, #proto.code do
        local ins = proto.code[i]
        if (ins % 64) == OP_LOADK then
            local a = (ins >> 6) & 0xFF
            if a < old_max then
                positions[#positions + 1] = i
            end
        end
    end

    if #positions == 0 then return 0 end

    -- increase maxstacksize
    proto.maxstacksize = old_max + 1

    -- process from end to beginning so earlier positions don't shift
    local count = 0
    for idx = #positions, 1, -1 do
        if count >= 8 then break end
        local pos = positions[idx]
        local ins = proto.code[pos]
        local a = (ins >> 6) & 0xFF

        -- insert after pos: MOVE high, a; LOADK a, zero; MOVE a, high
        local insert_at = pos + 1
        adjust_jumps(proto.code, insert_at, 3)
        table.insert(proto.code, insert_at, make_move(a, high_reg))     -- restore (will be at insert_at+2)
        table.insert(proto.code, insert_at, make_loadk(a, zero_kidx))    -- dummy overwrite (insert_at+1)
        table.insert(proto.code, insert_at, make_move(high_reg, a))       -- save (insert_at)
        count = count + 1
    end

    return count
end

local function split(proto)
    if type(proto) ~= 'userdata' then error("live_range_split: expected proto userdata") end
    local count = split_function(proto)
    for i = 1, #proto.p do
        if proto.p[i] then count = count + split_function(proto.p[i]) end
    end
    return count
end

return {
    split_function = split_function,
    split = split,
}
