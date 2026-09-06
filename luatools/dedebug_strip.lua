-- dedebug_strip.lua - 重建调试信息 (debug_strip 移除后无法恢复, 但可以重建 lineinfo)
-- debug_strip 移除了 lineinfo/locvars/upvalue names, 这些信息无法恢复
-- 但可以重建 lineinfo (全 0), 使字节码格式完整
--
-- 用法: local dedbg = require("dedebug_strip"); dedbg.restore(proto)

local luac = require("luac")

local dedebug_strip = {}

local function restore_function(proto)
    -- 重建 lineinfo (全 0)
    if #proto.lineinfo ~= #proto.code then
        local new_lineinfo = {}
        for i = 1, #proto.code do
            new_lineinfo[i] = 0
        end
        proto.lineinfo = new_lineinfo
    end

    -- locvars 无法恢复, 保持为空
    -- upvalue names 无法恢复, 保持为空

    -- 递归子函数
    for i = 1, #proto.p do
        restore_function(proto.p[i])
    end
end

function dedebug_strip.restore(proto, options)
    options = options or {}
    restore_function(proto)
    return true
end

-- CLI
if arg and arg[0] and arg[0]:match("dedebug_strip") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_dedbg.lua")

    local f = io.open(input, "rb")
    local data = f:read("*a")
    f:close()

    local p = luac.undump(data, false)
    dedebug_strip.restore(p)
    local out = luac.dump(p)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print("Input: " .. input .. " (" .. #data .. " bytes)")
    print("Output: " .. output .. " (" .. #out .. " bytes)")
    print("Restored lineinfo (all zeros), locvars/upvalue names cannot be restored")
    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return dedebug_strip
