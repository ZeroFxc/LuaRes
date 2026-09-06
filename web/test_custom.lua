-- 测试自定义模块：在每个 proto 末尾插入一条 NOP 风格的 MOVE 指令
local M = {}
M.name = "test_nop_insert"
M.label = "测试-NOP插入"
M.description = "自定义模块测试：在指令末尾插入 MOVE 0 0"

function M.apply(proto)
    local code = proto.code
    local n = proto.sizecode
    -- MOVE A B C: opcode=0(MOVE), A=0, B=0, C=0
    -- Lua 5.3 instruction: 0x00000000 = MOVE 0 0 0
    code[n+1] = 0
    proto.sizecode = n + 1
    return true
end

return M
