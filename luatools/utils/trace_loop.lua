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
        local refs = {}
        if op == luac.OP_LOADK then refs[#refs+1] = luac.GETARG_Bx(ins)
        elseif op == luac.OP_EXTRAARG then refs[#refs+1] = luac.GETARG_Ax(ins)
        elseif op ~= luac.OP_CLOSURE and op ~= luac.OP_JMP and op ~= luac.OP_FORLOOP
               and op ~= luac.OP_FORPREP and op ~= luac.OP_TFORLOOP then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            if b >= 256 then refs[#refs+1] = b-256 end
            if c >= 256 then refs[#refs+1] = c-256 end
        end
        for _, ref in ipairs(refs) do
            if ref >= #proto.k then
                results[#results+1] = string.format("%s pc=%d op=%d ref=%d >= #k=%d",
                    path, i-1, op, ref, #proto.k)
            end
        end
    end
    for i = 1, #proto.p do
        if proto.p[i] then check_proto(proto.p[i], path.."/p["..(i-1).."]", results) end
    end
end

for trial = 1, 200 do
    local p = luac.undump(bc, false)
    for _, name in ipairs(FORWARD_ORDER) do
        local fn = mods[name][FORWARD_FN[name]]
        pcall(fn, p, {})
    end
    local results = {}
    check_proto(p, "main", results)
    if #results > 0 then
        print(string.format("trial %d: %d overflows", trial, #results))
        for _, r in ipairs(results) do
            print("  "..r)
        end
        -- also dump the offending proto's code
        os.exit(1)
    end
    if trial % 20 == 0 then print(string.format("trial %d: clean", trial)) end
end
print("all 200 trials clean")
