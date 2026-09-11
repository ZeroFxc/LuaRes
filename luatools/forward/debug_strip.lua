-- debug_strip.lua - remove debug info (lineinfo, locvars, upvalue names)
-- Usage: lua luac_flatten.lua debug_strip <input.luac> <output.luac>
local luac = require("luac")

local function strip_function(proto)
    -- Clear lineinfo
    proto.lineinfo = {}
    -- Clear locvars
    proto.locvars = {}
    -- Clear upvalue names (keep instack/idx)
    for i = 1, #proto.upvalues do
        proto.upvalues[i].name = ""
    end
    -- Recurse
    for i = 1, proto.sizep do
        strip_function(proto.p[i])
    end
end

local function strip(input, output)
    if type(input) == 'userdata' then
        strip_function(input)
        return
    end
    local f = io.open(input, "rb")
    if not f then error("cannot open " .. input) end
    local data = f:read("*a")
    f:close()

    if data:byte(1) == string.byte('=') then
        data = string.dec(data)
    end

    local proto = luac.undump(data, true)
    print(string.format("Loaded: sizecode=%d sizek=%d sizep=%d",
        proto.sizecode, proto.sizek, proto.sizep))

    strip_function(proto)

    local out = luac.dump(proto)
    f = io.open(output_path, "wb")
    f:write(out)
    f:close()
    print(string.format("Stripped: %d bytes (was %d bytes)", #out, #data))

    local func = load(out)
    if func then
        print("Verification: bytecode loads OK")
    else
        print("WARNING: bytecode failed to load!")
    end
end

if arg and arg[0] and arg[0]:match("debug_strip") and arg[1] and arg[2] then
    strip(arg[1], arg[2])
end

return {
    strip_function = strip_function,
    strip = strip,
}
