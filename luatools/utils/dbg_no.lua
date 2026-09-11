package.path = package.path .. ";E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/utils/?.lua"
local luac = require('luac')

-- simple test
local src = 'print(6)\nprint("6")\nprint(6.6)'
local bc = string.dec(string.dump(load(src)), false)
local p = luac.undump(bc, false)

local opnames = {'MOVE','LOADK','LOADKX','LOADBOOL','LOADNIL','GETUPVAL','GETTABUP','GETTABLE','SETTABUP','SETUPVAL','SETTABLE','NEWTABLE','SELF','ADD','SUB','MUL','MOD','POW','DIV','IDIV','BAND','BOR','BXOR','SHL','SHR','UNM','NOT','LEN','CONCAT','JMP','EQ','LT','LE','TEST','TESTSET','CALL','TAILCALL','RETURN','FORLOOP','FORPREP','TFORCALL','TFORLOOP','SETLIST','CLOSURE','VARARG','EXTRAARG'}

local function dump(p, label)
    print('=== ' .. label .. ' (code=' .. #p.code .. ' k=' .. #p.k .. ' maxstack=' .. p.maxstacksize .. ') ===')
    for i = 1, #p.code do
        local ins = p.code[i]
        local op = ins & 0x3F
        local a = (ins >> 6) & 0xFF
        local b = (ins >> 23) & 0x1FF
        local c = (ins >> 14) & 0x1FF
        local bx = ins >> 14
        local sbx = bx - 131071
        local name = opnames[op+1] or ('op'..op)
        if op == 1 or op == 2 then -- LOADK/LOADKX
            print(string.format('%3d: %-10s A=%d Bx=%d (k[%d]=%s)', i, name, a, bx, bx+1, tostring(p.k[bx+1])))
        elseif op == 30 then -- JMP
            print(string.format('%3d: %-10s sBx=%d', i, name, sbx))
        elseif op >= 13 and op <= 24 then -- arithmetic
            print(string.format('%3d: %-10s A=%d B=%d C=%d', i, name, a, b, c))
        else
            print(string.format('%3d: %-10s A=%d B=%d C=%d', i, name, a, b, c))
        end
    end
    print('constants:')
    for i = 1, #p.k do
        print(string.format('  k[%d] = %s (%s)', i, tostring(p.k[i]), type(p.k[i])))
    end
end

dump(p, 'before')
luac.num_obfuscate_c(p)
dump(p, 'after num_obfuscate')

-- try to run
print('--- running ---')
local e = luac.dump(p)
local f = load(e)
if f then
    local ok, err = pcall(f)
    if ok then print('RUN OK') else print('RUN FAIL: ' .. tostring(err)) end
else
    print('LOAD FAIL')
end
