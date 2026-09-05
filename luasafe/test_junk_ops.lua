local luac = require("luac")

local function make_loadk(a, bx)
    return (1) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)
end
local function make_test(a, c)
    return (34) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14)
end
local function make_jmp(sbx)
    local bx = sbx + 131071
    return (30) | ((bx & 0x3FFFF) << 14)
end

-- 正确的操作码
local junk_types = {
    {name="MOVE", op=0},
    {name="LOADK", op=1},
    {name="LOADBOOL", op=3},
    {name="LOADNIL", op=4},
    {name="NEWTABLE", op=11},
    {name="NOT", op=27},
    {name="LEN", op=28},
    {name="UNM", op=25},
    {name="BNOT", op=26},
    {name="ADD", op=13},
    {name="SUB", op=14},
    {name="MUL", op=15},
    {name="SELF", op=12},
    {name="GETTABLE", op=7},
    {name="SETTABLE", op=10},
    {name="CONCAT", op=29},
    {name="CALL", op=36},
    {name="RETURN", op=38},
}

for _, jt in ipairs(junk_types) do
    local func = load("print('hello')")
    local bc = string.dec(string.dump(func))
    local p = luac.undump(bc, false)

    -- 构造垃圾指令（iABC 格式，A=4, B=4, C=4）
    local junk = jt.op | ((4 & 0xFF) << 6) | ((4 & 0x1FF) << 14) | ((4 & 0x1FF) << 23)

    local branch = {
        make_loadk(3, 0),
        make_test(3, 0),
        make_jmp(1),
        junk,
    }
    for i = #branch, 1, -1 do
        table.insert(p.code, 3, branch[i])
    end

    local out = luac.dump(p)
    local ok, f = pcall(load, out)
    local exec_ok = false
    local err = ""
    if ok then
        local old_print = print
        print = function() end
        exec_ok, err = pcall(f)
        print = old_print
    end
    print(string.format("%-10s op=%2d: load=%s exec=%s %s",
        jt.name, jt.op, tostring(ok), tostring(exec_ok),
        exec_ok and "OK" or ("err=" .. tostring(err or f))))
end
