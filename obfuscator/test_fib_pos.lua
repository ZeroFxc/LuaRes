local luac = require("luac")
local junk_jmp = require("junk_jmp")

local func = loadfile("E:/LuaRes/luasafe/test_multi_func.lua")
local bc = string.dec(string.dump(func))

-- 固定随机种子，复现错误
math.randomseed(12345)

local p = luac.undump(bc, false)

-- 手动注入 2 个 JMP 到指定位置，逐个测试
local test_positions = {
    {2},      -- GETUPVAL 和 LE 之间
    {3},      -- LE 和条件 JMP 之间（应该被 is_safe_pos 拒绝）
    {5},      -- RETURN 和 GETUPVAL(add) 之间
    {7},      -- GETUPVAL(fib) 和 SUB 之间
    {9},      -- CALL 和 GETUPVAL(fib) 之间
    {12},     -- CALL 和 TAILCALL 之间
    {14},     -- RETURN 和函数末尾之间
}

for _, positions in ipairs(test_positions) do
    local p2 = luac.undump(bc, false)
    for _, pos in ipairs(positions) do
        if junk_jmp.is_safe_pos(p2.p[3].code, pos) then
            junk_jmp.adjust_jumps(p2.p[3].code, pos, 1)
            table.insert(p2.p[3].code, pos, junk_jmp.make_jmp())
            print(string.format("pos %d: injected", pos))
        else
            print(string.format("pos %d: REJECTED", pos))
        end
    end
    p2.p[3].lineinfo = {}
    local out = luac.dump(p2)
    local ok, f = pcall(load, out)
    local exec_ok = false
    local err_msg = ""
    if ok then
        local old_print = print
        print = function() end
        exec_ok, err_msg = pcall(f)
        print = old_print
    end
    print(string.format("  -> load=%s exec=%s %s",
        tostring(ok), tostring(exec_ok),
        exec_ok and "" or ("err=" .. tostring(err_msg or f))))
end
