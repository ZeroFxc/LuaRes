package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

local FORWARD_ORDER = {
    'bool_obfuscate', 'num_obfuscate', 'str_split', 'const_hide', 'str_encrypt',
    'const_shuffle',
}
local FORWARD_FN = {
    bool_obfuscate='obfuscate', num_obfuscate='obfuscate', str_split='obfuscate',
    const_hide='process', str_encrypt='encrypt', const_shuffle='shuffle',
}

local src = io.open('utils/ad_test.lua', 'rb'):read('*a')
local bc = string.dec(string.dump(load(src)))
local mods = {}
for _, name in ipairs(FORWARD_ORDER) do mods[name] = require(name) end

local function dump_proto(proto, indent)
    indent = indent or ""
    print(string.format("%ssizek=%d #k=%d sizecode=%d #code=%d sizep=%d #p=%d",
        indent, proto.sizek, #proto.k, proto.sizecode, #proto.code, proto.sizep, #proto.p))
    print(indent.."k pool:")
    for i = 1, #proto.k do
        local v = proto.k[i]
        local s = v == nil and "NIL" or (type(v)..":"..tostring(v):sub(1,30))
        print(string.format("%s  k[%d]=%s", indent, i-1, s))
    end
    print(indent.."code:")
    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        local opname = luac.OP_NAMES and luac.OP_NAMES[op] or ("op"..op)
        local a = luac.GETARG_A(ins)
        local detail = ""
        if op == luac.OP_LOADK then
            detail = "Bx="..luac.GETARG_Bx(ins)
        elseif op == luac.OP_CLOSURE then
            detail = "Bx="..luac.GETARG_Bx(ins).." (proto idx)"
        elseif op == luac.OP_CALL then
            detail = "B="..luac.GETARG_B(ins).." C="..luac.GETARG_C(ins)
        elseif op == luac.OP_RETURN then
            detail = "B="..luac.GETARG_B(ins)
        elseif op == luac.OP_JMP or op == luac.OP_FORLOOP or op == luac.OP_FORPREP then
            detail = "sBx="..luac.GETARG_sBx(ins)
        else
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            if b >= 256 then detail = detail.." B=k["..(b-256).."]" else detail = detail.." B=R"..b end
            if c >= 256 then detail = detail.." C=k["..(c-256).."]" else detail = detail.." C=R"..c end
        end
        print(string.format("%s  [%d] %s A=%d %s", indent, i-1, opname, a, detail))
    end
    for i = 1, #proto.p do
        if proto.p[i] then
            print(indent.."sub proto "..(i-1)..":")
            dump_proto(proto.p[i], indent.."  ")
        end
    end
end

for trial = 1, 30 do
    local p = luac.undump(bc, false)
    for _, name in ipairs(FORWARD_ORDER) do
        local fn = mods[name][FORWARD_FN[name]]
        pcall(fn, p, {})
    end
    local enc = luac.dump(p)
    local f, lerr = load(enc)
    if not f then
        print(string.format("trial %d: LOAD FAILED: %s", trial, tostring(lerr)))
        dump_proto(p)
        os.exit(1)
    end
    local old_print = print
    print = function() end
    local ok, r = pcall(f)
    print = old_print
    if not ok then
        print(string.format("trial %d: RUN FAILED: %s", trial, tostring(r):sub(1,200)))
        dump_proto(p)
        os.exit(1)
    end
    print(string.format("trial %d: ok", trial))
end
print("all ok")
