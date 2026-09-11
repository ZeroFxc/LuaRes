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

local function collect_refs(proto, path)
    local refs = {}
    for i = 1, #proto.code do
        local ins = proto.code[i]
        local op = luac.GET_OPCODE(ins)
        if op == luac.OP_LOADK then
            local bx = luac.GETARG_Bx(ins)
            refs[#refs+1] = {path=path, pc=i-1, op="LOADK", idx=bx, val=const_val(proto.k[bx+1])}
        elseif op == luac.OP_EXTRAARG then
            local ax = luac.GETARG_Ax(ins)
            refs[#refs+1] = {path=path, pc=i-1, op="EXTRAARG", idx=ax, val=const_val(proto.k[ax+1])}
        elseif op ~= luac.OP_CLOSURE and op ~= luac.OP_JMP and op ~= luac.OP_FORLOOP
               and op ~= luac.OP_FORPREP and op ~= luac.OP_TFORLOOP then
            local b = luac.GETARG_B(ins)
            local c = luac.GETARG_C(ins)
            if b >= BITRK then
                local idx = b - BITRK
                refs[#refs+1] = {path=path, pc=i-1, op="iABC", field="B", idx=idx, val=const_val(proto.k[idx+1])}
            end
            if c >= BITRK then
                local idx = c - BITRK
                refs[#refs+1] = {path=path, pc=i-1, op="iABC", field="C", idx=idx, val=const_val(proto.k[idx+1])}
            end
        end
    end
    -- recurse into sub-protos using actual count (not stale sizep)
    local actual_sizep = #proto.p
    for i = 1, actual_sizep do
        if proto.p[i] then
            local sub = collect_refs(proto.p[i], path.."/p["..(i-1).."]")
            for _, r in ipairs(sub) do refs[#refs+1] = r end
        end
    end
    return refs
end

local function find_proto(proto, path_parts, idx)
    if idx > #path_parts then return proto end
    local part = path_parts[idx]
    if part == "main" then return find_proto(proto, path_parts, idx+1) end
    local pidx = tonumber(part:match("p%[(%d+)%]"))
    if not pidx then return proto end
    return find_proto(proto.p[pidx+1], path_parts, idx+1)
end

for trial = 1, 50 do
    local p = luac.undump(bc, false)
    for _, name in ipairs(FORWARD_ORDER) do
        local fn = mods[name][FORWARD_FN[name]]
        pcall(fn, p, {})
    end

    local refs_before = collect_refs(p, "main")

    local cs = require('const_shuffle')
    cs.shuffle_function(p)

    local mismatches = {}
    for _, r in ipairs(refs_before) do
        local path_parts = {}
        for part in r.path:gmatch("[^/]+") do path_parts[#path_parts+1] = part end
        local proto = find_proto(p, path_parts, 1)

        local ins = proto.code[r.pc+1]
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
            local new_val = const_val(proto.k[new_idx+1])
            if new_val ~= r.val then
                mismatches[#mismatches+1] = string.format(
                    "%s pc=%d op=%s%s old_idx=%d(%s) new_idx=%d(%s)",
                    r.path, r.pc, r.op, r.field and ("."..r.field) or "", r.idx, r.val, new_idx, new_val)
            end
        else
            mismatches[#mismatches+1] = string.format(
                "%s pc=%d op=%s%s old_idx=%d(%s) -> NO CONST REF (op=%d)",
                r.path, r.pc, r.op, r.field and ("."..r.field) or "", r.idx, r.val, op)
        end
    end

    if #mismatches > 0 then
        print(string.format("trial %d: %d mismatches", trial, #mismatches))
        for i = 1, math.min(#mismatches, 40) do
            print("  "..mismatches[i])
        end
        os.exit(1)
    end
    print(string.format("trial %d: ok (%d refs)", trial, #refs_before))
end
print("all ok")
