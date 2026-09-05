-- deprotect.lua - multi-pass bytecode deobfuscation pipeline
-- Combines: fix_anti_td -> deop48 -> dejunk_jmp -> dejunk_loadk ->
--           dejunk_move -> deopaque_junk
--
-- 用法: local deprotect = require("deprotect"); local cleaned = deprotect.clean(bytecode)

local luac = require("luac")

local function load_mod(name)
    local ok, m = pcall(require, name)
    if not ok then return nil end
    return m
end

local function clean(bytecode, options)
    options = options or {}

    local data = bytecode
    if type(data) == "string" and data:byte(1) == string.byte('=') then
        data = string.dec(data)
    end

    local proto = luac.undump(data, false)
    local stats = {original_size = #data, passes = {}, removed = {}}

    -- 1. Remove OP_48 / invalid opcodes (>46)
    if not options.no_deop48 then
        local m = load_mod("deop48")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "deop48")
            stats.removed.deop48 = r
        end
    end

    -- 2. Remove junk JMP (sBx=0)
    if not options.no_dejunk_jmp then
        local m = load_mod("dejunk_jmp")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "dejunk_jmp")
            stats.removed.dejunk_jmp = r
        end
    end

    -- 3. Remove opaque predicate junk branches
    if not options.no_deopaque_junk then
        local m = load_mod("deopaque_junk")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "deopaque_junk")
            stats.removed.deopaque_junk = r
        end
    end

    -- 4. Remove junk LOADK (high register, unused)
    if not options.no_dejunk_loadk then
        local m = load_mod("dejunk_loadk")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "dejunk_loadk")
            stats.removed.dejunk_loadk = r
        end
    end

    -- 5. Remove junk MOVE (high register, unused)
    if not options.no_dejunk_move then
        local m = load_mod("dejunk_move")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "dejunk_move")
            stats.removed.dejunk_move = r
        end
    end

    -- 6. Fix anti-TD (header poisoning, junk upvalues) — MUST run last,
    --    because it changes maxstacksize which would confuse earlier passes
    if not options.no_fix_anti_td then
        local m = load_mod("fix_anti_td")
        if m and m.fix then
            local r = m.fix(proto)
            table.insert(stats.passes, "fix_anti_td")
            stats.removed.fix_anti_td = r
        end
    end

    local out = luac.dump(proto)
    stats.cleaned_size = #out
    stats.ratio = string.format("%.1f%%", (#out / #data) * 100)
    return out, stats
end

-- CLI
if arg and arg[0] and arg[0]:match("deprotect") and arg[1] then
    local input = arg[1]
    local output = arg[2] or input:gsub("%.lua$", "_clean.lua")
    local options = {}
    for i = 3, #arg do
        if arg[i] == "--no-fix-anti-td" then options.no_fix_anti_td = true
        elseif arg[i] == "--no-deop48" then options.no_deop48 = true
        elseif arg[i] == "--no-dejunk-jmp" then options.no_dejunk_jmp = true
        elseif arg[i] == "--no-deopaque-junk" then options.no_deopaque_junk = true
        elseif arg[i] == "--no-dejunk-loadk" then options.no_dejunk_loadk = true
        elseif arg[i] == "--no-dejunk-move" then options.no_dejunk_move = true
        end
    end

    local f = io.open(input, "rb")
    if not f then error("cannot open " .. input) end
    local data = f:read("*a")
    f:close()

    local out, stats = clean(data, options)

    local fout = io.open(output, "wb")
    fout:write(out)
    fout:close()

    print(string.format("Cleaned: %d -> %d bytes (%s)", stats.original_size, stats.cleaned_size, stats.ratio))
    print("Passes: " .. table.concat(stats.passes, " -> "))
    for k, v in pairs(stats.removed) do
        print("  " .. k .. ": " .. v .. " instructions removed")
    end

    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return setmetatable({}, {
    __call = function(_, ...) return clean(...) end,
    __index = { clean = clean },
})
