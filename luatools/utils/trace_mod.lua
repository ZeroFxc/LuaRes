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

local function check_proto(proto, path, results)
    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        if op == 46 then  -- EXTRAARG
            local ax = luac.GETARG_Ax(ins)
            if ax >= #proto.k then
                results[#results+1] = string.format("%s pc=%d EXTRAARG Ax=%d >= #k=%d", path, i-1, ax, #proto.k)
                -- dump surrounding instructions
                for j = math.max(1, i-3), math.min(#proto.code, i+1) do
                    local ins2 = proto.code[j]
                    local op2 = luac.GET_OPCODE(ins2)
                    local a2 = luac.GETARG_A(ins2)
                    local detail = ""
                    if op2 == 1 then detail = "LOADK Bx="..luac.GETARG_Bx(ins2)
                    elseif op2 == 2 then detail = "LOADKX"
                    elseif op2 == 46 then detail = "EXTRAARG Ax="..luac.GETARG_Ax(ins2)
                    else detail = string.format("op=%d A=%d B=%d C=%d", op2, a2, luac.GETARG_B(ins2), luac.GETARG_C(ins2))
                    end
                    results[#results+1] = string.format("    [%d] %s", j-1, detail)
                end
            end
        end
    end
    for i = 1, #proto.p do
        if proto.p[i] then check_proto(proto.p[i], path.."/p["..(i-1).."]", results) end
    end
end

for trial = 1, 100 do
    local p = luac.undump(bc, false)
    for mi, name in ipairs(FORWARD_ORDER) do
        local fn = mods[name][FORWARD_FN[name]]
        pcall(fn, p, {})
        local results = {}
        check_proto(p, "main", results)
        if #results > 0 then
            print(string.format("trial %d: overflow after %s", trial, name))
            for _, r in ipairs(results) do print("  "..r) end
            os.exit(1)
        end
    end
    if trial % 10 == 0 then print(string.format("trial %d: clean", trial)) end
end
print("all clean")
