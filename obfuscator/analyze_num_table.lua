-- 字节码分析工具
local luac = require('luac')

local opnames = {
    [0]='MOVE',[1]='LOADK',[2]='LOADKX',[3]='LOADBOOL',[4]='LOADNIL',
    [5]='GETUPVAL',[6]='GETTABUP',[7]='GETTABLE',[8]='SETTABUP',
    [9]='SETTABLE',[10]='NEWTABLE',[11]='SELF',[12]='ADD',[13]='SUB',
    [14]='MUL',[15]='MOD',[16]='POW',[17]='DIV',[18]='IDIV',
    [19]='BAND',[20]='BOR',[21]='BXOR',[22]='SHL',[23]='SHR',
    [24]='UNM',[25]='BNOT',[26]='NOT',[27]='LEN',[28]='CONCAT',
    [29]='JMP',[30]='EQ',[31]='LT',[32]='LE',[33]='TEST',
    [34]='TESTSET',[35]='CALL',[36]='TAILCALL',[37]='RETURN',
    [38]='FORLOOP',[39]='FORPREP',[40]='TFORCALL',[41]='TFORLOOP',
    [42]='SETLIST',[43]='CLOSURE',[44]='VARARG',[45]='EXTRAARG'
}

local function analyze_proto(proto, depth, name)
    local indent = string.rep('  ', depth)
    print(string.format('%s=== %s ===', indent, name))
    print(string.format('%s  sizecode=%d sizek=%d sizep=%d maxstack=%d',
        indent, #proto.code, #proto.k, #proto.p, proto.maxstacksize))

    -- 统计操作码
    local opcount = {}
    for i = 1, #proto.code do
        local op = luac.GET_OPCODE(proto.code[i])
        opcount[op] = (opcount[op] or 0) + 1
    end
    io.write(indent .. '  opcodes: ')
    local parts = {}
    for op, cnt in pairs(opcount) do
        parts[#parts+1] = string.format('%s=%d', opnames[op] or ('OP'..op), cnt)
    end
    table.sort(parts)
    print(table.concat(parts, ', '))

    -- 打印常量
    if #proto.k > 0 then
        io.write(indent .. '  constants: ')
        local kp = {}
        for i = 1, math.min(#proto.k, 20) do
            local v = proto.k[i]
            if type(v) == 'string' then
                kp[#kp+1] = string.format('k[%d]="%s"', i-1, #v > 20 and v:sub(1,20)..'...' or v)
            else
                kp[#kp+1] = string.format('k[%d]=%s', i-1, tostring(v))
            end
        end
        print(table.concat(kp, ', '))
    end

    -- 打印完整指令
    print(indent .. '  code:')
    for i = 1, #proto.code do
        local inst = proto.code[i]
        local op = luac.GET_OPCODE(inst)
        local a = luac.GETARG_A(inst)
        local b = luac.GETARG_B(inst)
        local c = luac.GETARG_C(inst)
        local bx = luac.GETARG_Bx(inst)
        local sbx = luac.GETARG_sBx(inst)
        local opname = opnames[op] or ('OP'..op)

        local detail = ''
        if op == 1 then -- LOADK
            detail = string.format(' ; k[%d]=%s', bx, tostring(proto.k[bx+1]))
        elseif op == 10 then -- NEWTABLE
            detail = string.format(' ; B=%d C=%d (array=%d, hash=%d)', b, c, b, c)
        elseif op == 42 then -- SETLIST
            detail = string.format(' ; B=%d C=%d (count=%d, page=%d)', b, c, b, c)
        elseif op == 29 then -- JMP
            detail = string.format(' ; sBx=%d', sbx)
        elseif op == 38 or op == 39 then -- FORLOOP/FORPREP
            detail = string.format(' ; sBx=%d', sbx)
        elseif op == 43 then -- CLOSURE
            detail = string.format(' ; p[%d]', bx)
        elseif op >= 30 and op <= 32 then -- EQ/LT/LE
            local rk = c >= 256 and ('k['..(c-256)..']='..tostring(proto.k[c-255])) or ('R'..c)
            detail = string.format(' ; %s', rk)
        end

        print(string.format('%s    [%3d] %-10s A=%-3d B=%-4d C=%-4d%s',
            indent, i-1, opname, a, b, c, detail))
    end
    print()

    -- 递归子函数
    for i = 1, #proto.p do
        analyze_proto(proto.p[i], depth + 1, string.format('%s.p[%d]', name, i-1))
    end
end

local function analyze_file(path, label)
    print('================================================================')
    print('FILE: ' .. path .. ' (' .. label .. ')')
    print('================================================================')
    local src = io.open(path):read('*a')
    local func = load(src)
    local bc = string.dec(string.dump(func))
    local proto = luac.undump(bc, false)
    analyze_proto(proto, 0, 'main')
    print()
end

analyze_file('../num_test.lua', 'NUMBER TEST')
analyze_file('../table_test.lua', 'TABLE TEST')
