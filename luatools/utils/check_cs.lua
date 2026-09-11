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

local BITRK = 256

local function const_val(v)
    if v == nil then return "NIL" end
    if type(v) == "boolean" then return "BOOL:"..tostring(v) end
    if type(v) == "number" then return "NUM:"..tostring(v) end
    if type(v) == "string" then return "STR:"..v:sub(1,20) end
    return type(v)
end

local function collect_refs(proto)
    local refs = {}
    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(ins)
            refs[#refs+1] = {pc=i-1, op="LOADK", idx=bx, val=const_val(proto.k[bx+1])}
        elseif op == luac.OP_EXTRAARG then
            local ax = luac.GETARG_Ax(ins)
            refs[#refs+1] = {pc=i-1, op="EXTRAARG", idx=ax, val=const_val(proto.k[ax+1])}
        elseif op ~= luac.OP_CLOSURE and op ~= luac.OP_JMP and op ~= luac.OP_FORLOOP
               and op ~= luac.OP_FORPREP and op ~= luac.OP_TFORLOOP then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            if b >= BITRK then
                local idx = b - BITRK
                refs[#refs+1] = {pc=i-1, op=luac.OP_NAMES[op] or "op"..op, field="B", idx=idx, val=const_val(proto.k[idx+1])}
            end
            if c >= BITRK then
                local idx = c - BITRK
                refs[#refs+1] = {pc=i-1, op=luac.OP_NAMES[op] or "op"..op, field="C", idx=idx, val=const_val(proto.k[idx+1])}
            end
        end
    end
    return refs
end

for trial = 1, 50 do
    local p = luac.undump(bc, false)
    for _, name in ipairs(FORWARD_ORDER) do
        local fn = mods[name][FORWARD_FN[name]]
        pcall(fn, p, {})
    end

    -- before shuffle
    local refs_before = collect_refs(p)
    local k_before = {}
    for i = 1, #p.k do k_before[i] = p.k[i] end

    -- run const_shuffle
    local cs = require('const_shuffle')
    cs.shuffle_function(p)

    -- after shuffle: check each ref
    local mismatches = {}
    for _, r in ipairs(refs_before) do
        -- find the instruction at same pc and check its referenced constant
        local ins = p.code[r.pc+1]
        local op = luac.GET_OPCODE(ins)
        local new_idx = nil
        if r.op == "LOADK" and op == luac.OP_LOADK then
            new_idx = luac.GETARG_Bx(ins)
        elseif r.op == "EXTRAARG" and op == luac.OP_EXTRAARG then
            new_idx = luac.GETARG_Ax(ins)
        elseif r.field == "B" then
            local b = luac.GETARG_B(ins)
            if b >= BITRK then new_idx = b - BITRK end
        elseif r.field == "C" then
            local c = luac.GETARG_C(ins)
            if c >= BITRK then new_idx = c - BITRK end
        end

        if new_idx ~= nil then
            local new_val = const_val(p.k[new_idx+1])
            if new_val ~= r.val then
                mismatches[#mismatches+1] = string.format(
                    "pc=%d op=%s%s old_idx=%d(%s) new_idx=%d(%s)",
                    r.pc, r.op, r.field and ("."..r.field) or "", r.idx, r.val, new_idx, new_val)
            end
        else
            -- instruction no longer references a constant (opcode changed?)
            mismatches[#mismatches+1] = string.format(
                "pc=%d op=%s%s old_idx=%d(%s) -> NO CONST REF NOW (op=%d)",
                r.pc, r.op, r.field and ("."..r.field) or "", r.idx, r.val, op)
        end
    end

    if #mismatches > 0 then
        print(string.format("trial %d: %d mismatches", trial, #mismatches))
        for i = 1, math.min(#mismatches, 30) do
            print("  "..mismatches[i])
        end
        -- also dump k pool
        print("  k pool after:")
        for i = 1, math.min(#p.k, 50) do
            if p.k[i] ~= nil then
                print(string.format("    k[%d]=%s", i-1, const_val(p.k[i])))
            end
        end
        os.exit(1)
    end
    print(string.format("trial %d: ok (%d refs checked)", trial, #refs_before))
end
print("all trials ok")
