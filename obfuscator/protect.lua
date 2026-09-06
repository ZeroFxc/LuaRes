-- protect.lua - multi-pass bytecode protection pipeline
-- Combines: debug_strip -> const_shuffle -> instruction_mutate ->
--           opaque_predicate -> control_flow_flatten -> junk_obfuscate
--
-- Usage as library:
--   local protect = require("protect")
--   local protected_bytes = protect.protect(bytecode_string, options)
--
-- Usage as CLI:
--   lua protect.lua <input.lua|.luac> <output.luac> [options]
--   Options: --no-flatten, --no-obfuscate, --no-opaque, --no-mutate,
--            --no-shuffle, --no-strip

local luac = require("luac")

-- Lazy-load pass modules
local function load_mod(name)
    local ok, m = pcall(require, name)
    if not ok then return nil end
    return m
end

local function protect(bytecode, options)
    options = options or {}
    if options.seed then
        math.randomseed(options.seed)
    else
        math.randomseed(os.time())
    end

    local data = bytecode
    if type(data) == "string" and data:byte(1) == string.byte('=') then
        data = string.dec(data)
    end

    local proto = luac.undump(data, true)
    local stats = {original_size = #data, passes = {}}

    -- 1. Debug strip
    if not options.no_strip then
        local m = load_mod("debug_strip")
        if m and m.strip_function then
            m.strip_function(proto)
            table.insert(stats.passes, "debug_strip")
        end
    end

    -- 2. Constant shuffle
    if not options.no_shuffle then
        local m = load_mod("const_shuffle")
        if m and m.shuffle_function then
            m.shuffle_function(proto)
            table.insert(stats.passes, "const_shuffle")
        end
    end

    -- 3. Instruction mutate
    if not options.no_mutate then
        local m = load_mod("instruction_mutate")
        if m and m.mutate_function then
            m.mutate_function(proto)
            table.insert(stats.passes, "instruction_mutate")
        end
    end

    -- 4. Control flow flatten (must run before opaque_predicate, because
    --    opaque's dead code would confuse flatten's basic block detection)
    if not options.no_flatten then
        local m = load_mod("luac_flatten")
        if m and m.flatten_proto then
            m.flatten_proto(proto)
            table.insert(stats.passes, "control_flow_flatten")
        end
    end

    -- 5. Opaque predicate (after flatten, so it wraps the flattened dispatch)
    if not options.no_opaque then
        local m = load_mod("opaque_predicate")
        if m and m.process_function then
            m.process_function(proto)
            table.insert(stats.passes, "opaque_predicate")
        end
    end

    -- 6. Junk obfuscate (last, fixes all jump offsets)
    if not options.no_obfuscate then
        local m = load_mod("luac_obfuscate")
        if m and m.obfuscate_proto then
            m.obfuscate_proto(proto)
            table.insert(stats.passes, "junk_obfuscate")
        end
    end

    -- 7. Anti-TD decompiler protection (poison headers, strip lineinfo, junk source)
    if not options.no_anti_td then
        local m = load_mod("anti_td")
        if m and m.protect then
            m.protect(proto, options.anti_td_options)
            table.insert(stats.passes, "anti_td")
        end
    end

    -- 8. Junk LOADK instructions (load numeric constants to high registers)
    if not options.no_junk_loadk then
        local m = load_mod("junk_loadk")
        if m and m.inject then
            m.inject(proto, {
                count = options.junk_loadk_count or 30,
            })
            table.insert(stats.passes, "junk_loadk")
        end
    end

    -- 9. Junk JMP instructions (JMP sBx=0, harmless NOP-like jumps)
    if not options.no_junk_jmp then
        local m = load_mod("junk_jmp")
        if m and m.inject then
            m.inject(proto, {
                count = options.junk_jmp_count or 30,
            })
            table.insert(stats.passes, "junk_jmp")
        end
    end

    -- 10. Junk MOVE instructions (high register copies, harmless)
    if not options.no_junk_move then
        local m = load_mod("junk_move")
        if m and m.inject then
            m.inject(proto, {
                count = options.junk_move_count or 20,
            })
            table.insert(stats.passes, "junk_move")
        end
    end

    -- 11. Opaque predicate junk branches (dead code with TEST+JMP guards)
    if not options.no_opaque_junk then
        local m = load_mod("opaque_junk")
        if m and m.inject then
            m.inject(proto, {
                count = options.opaque_junk_count or 15,
            })
            table.insert(stats.passes, "opaque_junk")
        end
    end

    -- 12. OP_48 junk instructions (andlua VM ignores invalid opcode 48)
    --    Must run last, injects at end of code / after last RETURN
    if not options.no_op48 then
        local m = load_mod("op48_junk")
        if m and m.inject then
            m.inject(proto, {
                count = options.op48_count or 50,
                mode = options.op48_mode or "blocks",
            })
            table.insert(stats.passes, "op48_junk")
        end
    end

    local out = luac.dump(proto)
    stats.protected_size = #out
    stats.ratio = string.format("%.1f%%", (#out / #data) * 100)
    return out, stats
end

-- CLI interface
if arg and arg[0] and arg[0]:match("protect") and arg[1] and arg[2] then
    local input_path = arg[1]
    local output_path = arg[2]
    local options = {}
    for i = 3, #arg do
        if arg[i] == "--no-flatten" then options.no_flatten = true
        elseif arg[i] == "--no-obfuscate" then options.no_obfuscate = true
        elseif arg[i] == "--no-opaque" then options.no_opaque = true
        elseif arg[i] == "--no-mutate" then options.no_mutate = true
        elseif arg[i] == "--no-shuffle" then options.no_shuffle = true
        elseif arg[i] == "--no-strip" then options.no_strip = true
        elseif arg[i] == "--no-anti-td" then options.no_anti_td = true
        elseif arg[i] == "--no-op48" then options.no_op48 = true
        elseif arg[i]:match("^--op48%-count=") then options.op48_count = tonumber(arg[i]:match("=(%d+)"))
        elseif arg[i]:match("^--op48%-mode=") then options.op48_mode = arg[i]:match("=(%w+)")
        elseif arg[i] == "--no-junk-jmp" then options.no_junk_jmp = true
        elseif arg[i]:match("^--junk%-jmp%-count=") then options.junk_jmp_count = tonumber(arg[i]:match("=(%d+)"))
        elseif arg[i] == "--no-junk-loadk" then options.no_junk_loadk = true
        elseif arg[i]:match("^--junk%-loadk%-count=") then options.junk_loadk_count = tonumber(arg[i]:match("=(%d+)"))
        elseif arg[i] == "--no-junk-move" then options.no_junk_move = true
        elseif arg[i]:match("^--junk%-move%-count=") then options.junk_move_count = tonumber(arg[i]:match("=(%d+)"))
        elseif arg[i] == "--no-opaque-junk" then options.no_opaque_junk = true
        elseif arg[i]:match("^--opaque%-junk%-count=") then options.opaque_junk_count = tonumber(arg[i]:match("=(%d+)"))
        end
    end

    local f = io.open(input_path, "rb")
    if not f then error("cannot open " .. input_path) end
    local data = f:read("*a")
    f:close()

    -- If input is .lua source, compile first
    if input_path:match("%.lua$") then
        local func, err = loadfile(input_path)
        if not func then error("compile error: " .. err) end
        data = string.dec(string.dump(func))
    end

    local out, stats = protect(data, options)

    f = io.open(output_path, "wb")
    f:write(out)
    f:close()

    print(string.format("Protected: %d -> %d bytes (%s)", stats.original_size, stats.protected_size, stats.ratio))
    print("Passes: " .. table.concat(stats.passes, " -> "))

    local func = load(out)
    if func then
        print("Verification: bytecode loads OK")
    else
        print("WARNING: bytecode failed to load!")
    end
end

return setmetatable({}, {
    __call = function(_, ...) return protect(...) end,
    __index = { protect = protect },
})
