package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'const_hide', 'str_encrypt',
}
local FORWARD_FN = {
    bool_obfuscate='obfuscate', num_obfuscate='obfuscate', str_split='obfuscate',
    const_hide='process', str_encrypt='encrypt',
}

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local mods = {}
for _, name in ipairs(FORWARD_ORDER) do mods[name] = require(name) end

local function check_proto(proto, path)
    local max_ref = -1
    local max_ref_pc = -1
    local max_ref_op = ""
    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        local ref = -1
        if op == luac.OP_LOADK then ref = luac.GETARG_Bx(ins)
        elseif op == luac.OP_EXTRAARG then ref = luac.GETARG_Ax(ins)
        elseif op ~= luac.OP_CLOSURE and op ~= luac.OP_JMP and op ~= luac.OP_FORLOOP
               and op ~= luac.OP_FORPREP and op ~= luac.OP_TFORLOOP then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            if b >= 256 then ref = math.max(ref, b-256) end
            if c >= 256 then ref = math.max(ref, c-256) end
        end
        if ref > max_ref then
            max_ref = ref
            max_ref_pc = i-1
            max_ref_op = luac.OP_NAMES and luac.OP_NAMES[op] or ("op"..op)
        end
    end
    if max_ref >= #proto.k then
        print(string.format("  OVERFLOW! %s: max_ref=%d >= #k=%d at pc=%d op=%s",
            path, max_ref, #proto.k, max_ref_pc, max_ref_op))
        -- dump the offending instruction
        local ins = proto.code[max_ref_pc+1]
        local a = luac.GETARG_A(ins)
        if luac.GET_OPCODE(ins) == luac.OP_LOADK then
            print(string.format("    LOADK A=%d Bx=%d (k[%d]=%s)", a, luac.GETARG_Bx(ins), luac.GETARG_Bx(ins), tostring(proto.k[luac.GETARG_Bx(ins)+1])))
        else
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            print(string.format("    %s A=%d B=%d C=%d", max_ref_op, a, b, c))
        end
    end
    for i = 1, #proto.p do
        if proto.p[i] then check_proto(proto.p[i], path.."/p["..(i-1).."]") end
    end
end

local p = luac.undump(bc, false)
print("=== initial ===")
check_proto(p, "main")

for _, name in ipairs(FORWARD_ORDER) do
    local fn = mods[name][FORWARD_FN[name]]
    pcall(fn, p, {})
    print("=== after "..name.." ===")
    check_proto(p, "main")
end
