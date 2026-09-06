-- fix_maxstack: 扫描所有 proto 的所有指令, 将 maxstacksize 修正为实际最大寄存器引用+1
-- 用于修复多模块叠加后 maxstacksize 与实际寄存器引用不一致的问题
local luac = require('luac')

local BITRK = 0x100

local function fix_proto(proto)
    local max_reg = proto.maxstacksize - 1
    if max_reg < 0 then max_reg = 0 end

    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        local a = luac.GETARG_A(ins)
        if a > max_reg then max_reg = a end
        local b = luac.GETARG_B(ins)
        if b < BITRK and b > max_reg then max_reg = b end
        local c = luac.GETARG_C(ins)
        if c < BITRK and c > max_reg then max_reg = c end
    end

    -- maxstacksize 是 unsigned char, 最大 255, 对应寄存器 0-254
    -- 如果引用了 R255, 无法用 maxstacksize 覆盖, 这是真正的溢出
    local needed = max_reg + 1
    if needed > 255 then
        -- 钳位到 255, 但 R255 仍越界 (调用方应避免使用 R255)
        needed = 255
    end
    if needed > proto.maxstacksize then
        proto.maxstacksize = needed
    end

    -- 递归子 proto
    for i = 1, #proto.p do
        fix_proto(proto.p[i])
    end
end

local function fix(proto)
    fix_proto(proto)
end

return { fix = fix }
