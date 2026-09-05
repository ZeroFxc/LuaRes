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

-- 各种垃圾指令
local junk_types = {
    {name="MOVE", inst=function() return (0) | ((4 & 0xFF) << 6) | ((5 & 0x1FF) << 23) end},
    {name="LOADK", inst=function() return make_loadk(4, 0) end},
    {name="NEWTABLE", inst=function() return (10) | ((4 & 0xFF) << 6) end},
    {name="NOT", inst=function() return (27) | ((4 & 0xFF) << 6) | ((4 & 0x1FF) << 23) end},
    {name="LEN", inst=function() return (28) | ((4 & 0xFF) << 6) | ((4 & 0x1FF) << 23) end},
    {name="ADD", inst=function() return (13) | ((4 & 0xFF) << 6) | ((4 & 0x1FF) << 14) | ((4 & 0x1FF) << 23) end},
    {name="SELF", inst=function() return (12) | ((4 & 0xFF) << 6) | ((4 & 0x1FF) << 14) | ((4 & 0x1FF) << 23) end},
    {name="SETTABLE", inst=function() return (10) | ((4 & 0xFF) << 6) end},
    {name="GETTABLE", inst=function() return (7) | ((4 & 0xFF) << 6) | ((4 & 0x1FF) << 14) | ((4 & 0x1FF) << 23) end},
    {name="CONCAT", inst=function() return (29) | ((4 & 0xFF) << 6) | ((4 & 0x1FF) << 14) | ((5 & 0x1FF) << 23) end},
}

for _, jt in ipairs(junk_types) do
    local func = load("print('hello')")
    local bc = string.dec(string.dump(func))
    local p = luac.undump(bc, false)

    local branch = {
        make_loadk(3, 0),
        make_test(3, 0),
        make_jmp(1),
        jt.inst(),
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
    print(string.format("%-10s: load=%s exec=%s %s",
        jt.name, tostring(ok), tostring(exec_ok),
        exec_ok and "" or ("err=" .. tostring(err or f))))
end
