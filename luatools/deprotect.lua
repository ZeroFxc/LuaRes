-- deprotect.lua - multi-pass bytecode deobfuscation pipeline
-- 12 passes: deop48 -> de_junk_obfuscate -> deopaque_predicate -> deopaque_junk ->
--             dejunk_jmp -> dejunk_loadk -> dejunk_move -> deinstruction_mutate ->
--             deconst_shuffle -> dedebug_strip -> deflatten -> fix_anti_td
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

    -- 2. Remove luac_obfuscate junk (JMP + random garbage)
    if not options.no_de_junk_obfuscate then
        local m = load_mod("de_junk_obfuscate")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "de_junk_obfuscate")
            stats.removed.de_junk_obfuscate = r
        end
    end

    -- 3. Remove opaque_predicate dead code (LOADK+LOADK+LT+JMP+junk)
    if not options.no_deopaque_predicate then
        local m = load_mod("deopaque_predicate")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "deopaque_predicate")
            stats.removed.deopaque_predicate = r
        end
    end

    -- 4. Remove opaque_junk branches (LOADK+TEST(C=1)+JMP+junk)
    if not options.no_deopaque_junk then
        local m = load_mod("deopaque_junk")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "deopaque_junk")
            stats.removed.deopaque_junk = r
        end
    end

    -- 5. Remove junk JMP (sBx=0)
    if not options.no_dejunk_jmp then
        local m = load_mod("dejunk_jmp")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "dejunk_jmp")
            stats.removed.dejunk_jmp = r
        end
    end

    -- 6. Remove junk LOADK (high register, unused)
    -- Disabled by default: can expose out-of-bounds register instructions
    -- to executable paths, causing intermittent crashes. Enable with options.enable_dejunk_loadk=true
    if options.enable_dejunk_loadk and not options.no_dejunk_loadk then
        local m = load_mod("dejunk_loadk")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "dejunk_loadk")
            stats.removed.dejunk_loadk = r
        end
    end

    -- 7. Remove junk MOVE (high register, unused)
    -- Disabled by default: same reason as dejunk_loadk
    if options.enable_dejunk_move and not options.no_dejunk_move then
        local m = load_mod("dejunk_move")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "dejunk_move")
            stats.removed.dejunk_move = r
        end
    end

    -- 8. Remove instruction_mutate identity ops (ADD A,A,Kst(0))
    if not options.no_deinstruction_mutate then
        local m = load_mod("deinstruction_mutate")
        if m and m.remove then
            local r = m.remove(proto)
            table.insert(stats.passes, "deinstruction_mutate")
            stats.removed.deinstruction_mutate = r
        end
    end

    -- 9. Sort constant pool (beautify, cannot restore original order)
    if not options.no_deconst_shuffle then
        local m = load_mod("deconst_shuffle")
        if m and m.sort then
            local r = m.sort(proto)
            table.insert(stats.passes, "deconst_shuffle")
            stats.removed.deconst_shuffle = r
        end
    end

    -- 10. Restore lineinfo (all zeros, locvars/upvalue names cannot be restored)
    if not options.no_dedebug_strip then
        local m = load_mod("dedebug_strip")
        if m and m.restore then
            m.restore(proto)
            table.insert(stats.passes, "dedebug_strip")
        end
    end

    -- 11. Control flow flattening partial restore (conservative)
    if not options.no_deflatten then
        local m = load_mod("deflatten")
        if m and m.partial_restore then
            local r = m.partial_restore(proto)
            table.insert(stats.passes, "deflatten")
            stats.removed.deflatten = r
        end
    end

    -- 12. Fix anti-TD (header poisoning, junk upvalues) — MUST run last,
    --     because it changes maxstacksize which would confuse earlier passes
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
        elseif arg[i] == "--no-de-junk-obfuscate" then options.no_de_junk_obfuscate = true
        elseif arg[i] == "--no-deopaque-predicate" then options.no_deopaque_predicate = true
        elseif arg[i] == "--no-deinstruction-mutate" then options.no_deinstruction_mutate = true
        elseif arg[i] == "--no-deconst-shuffle" then options.no_deconst_shuffle = true
        elseif arg[i] == "--no-dedebug-strip" then options.no_dedebug_strip = true
        elseif arg[i] == "--no-deflatten" then options.no_deflatten = true
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
        print("  " .. k .. ": " .. v)
    end

    local ok = pcall(load, out)
    print("Load test: " .. tostring(ok))
end

return setmetatable({}, {
    __call = function(_, ...) return clean(...) end,
    __index = { clean = clean },
})
