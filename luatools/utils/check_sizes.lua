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

local function dump_sizes(proto, path)
    local non_nil = 0
    for i = 1, #proto.k do if proto.k[i] ~= nil then non_nil = non_nil + 1 end end
    print(string.format("%s: sizek=%d #k=%d non_nil=%d sizecode=%d #code=%d sizep=%d #p=%d",
        path, proto.sizek, #proto.k, non_nil, proto.sizecode, #proto.code, proto.sizep, #proto.p))
    -- show max referenced index in code
    local max_ref = -1
    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        if op == luac.OP_LOADK then max_ref = math.max(max_ref, luac.GETARG_Bx(ins))
        elseif op == luac.OP_EXTRAARG then max_ref = math.max(max_ref, luac.GETARG_Ax(ins))
        elseif op ~= luac.OP_CLOSURE and op ~= luac.OP_JMP and op ~= luac.OP_FORLOOP
               and op ~= luac.OP_FORPREP and op ~= luac.OP_TFORLOOP then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            if b >= 256 then max_ref = math.max(max_ref, b-256) end
            if c >= 256 then max_ref = math.max(max_ref, c-256) end
        end
    end
    print(string.format("  max_const_ref=%d", max_ref))
    -- show first few and last few k values
    if #proto.k > 0 then
        local show = {}
        for i = 1, math.min(5, #proto.k) do show[#show+1] = string.format("k[%d]=%s", i-1, tostring(proto.k[i]):sub(1,15)) end
        if #proto.k > 10 then
            for i = math.max(6, #proto.k-3), #proto.k do show[#show+1] = string.format("k[%d]=%s", i-1, tostring(proto.k[i]):sub(1,15)) end
        end
        print("  "..table.concat(show, ", "))
    end
    for i = 1, #proto.p do
        if proto.p[i] then dump_sizes(proto.p[i], path.."/p["..(i-1).."]") end
    end
end

local p = luac.undump(bc, false)
for _, name in ipairs(FORWARD_ORDER) do
    local fn = mods[name][FORWARD_FN[name]]
    pcall(fn, p, {})
end

print("=== BEFORE const_shuffle ===")
dump_sizes(p, "main")

print("\n=== AFTER const_shuffle ===")
local cs = require('const_shuffle')
cs.shuffle_function(p)
dump_sizes(p, "main")
