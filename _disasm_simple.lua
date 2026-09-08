local luac = require("luac")
local f = io.open("_simple_out.luac", "rb")
local data = f:read("*a")
f:close()
local p = luac.undump(data, false)
local function disasm(proto, indent)
    indent = indent or ""
    print(indent .. "=== proto: maxstack=" .. proto.maxstacksize .. " numparams=" .. proto.numparams .. " sizecode=" .. #proto.code .. " ===")
    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        local a = luac.GETARG_A(ins)
        local b = luac.GETARG_B(ins)
        local c = luac.GETARG_C(ins)
        local bx = luac.GETARG_Bx(ins)
        local sbx = luac.GETARG_sBx(ins)
        local name = luac.OPCODE_NAMES[op+1] or "?"
        if op == 1 or op == 2 or op == 44 then
            print(indent .. string.format("[%d] %s A=%d Bx=%d", i-1, name, a, bx))
        elseif op == 30 or op == 39 or op == 40 or op == 42 then
            print(indent .. string.format("[%d] %s A=%d sBx=%d", i-1, name, a, sbx))
        else
            print(indent .. string.format("[%d] %s A=%d B=%d C=%d", i-1, name, a, b, c))
        end
    end
    print(indent .. "--- K constants ---")
    for i = 1, #proto.k do
        local k = proto.k[i]
        if type(k) == "string" then
            print(indent .. string.format("  K[%d] = string(%d bytes): %q", i-1, #k, k:sub(1,30)))
        else
            print(indent .. string.format("  K[%d] = %s: %s", i-1, type(k), tostring(k)))
        end
    end
    if proto.p then
        for i = 1, #proto.p do
            disasm(proto.p[i], indent .. "  ")
        end
    end
end
disasm(p)
