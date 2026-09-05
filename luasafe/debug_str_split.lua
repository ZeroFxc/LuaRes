-- 逐步排查 str_split 和后续模块的组合
local luac = require('luac')
local str_enc = require('str_encrypt')
local str_split = require('str_split')

local src = io.open('../boolean.lua'):read('*a')
local func = load(src)
local bc = string.dec(string.dump(func))

local function save(data, name)
    local f = io.open(name, 'wb'); f:write(data); f:close()
end
local function load_proto(name)
    local f = io.open(name, 'rb'); local d = f:read('*a'); f:close(); return luac.undump(d, false)
end
local function test_run(label)
    local f = io.open('cur.luac', 'rb'); local d = f:read('*a'); f:close()
    local ok, fn = pcall(load, d)
    if not ok then print('  -> ' .. label .. ' 加载失败: ' .. tostring(fn)); return false end
    local old_print = print; local out = {}
    print = function(...) local p={} for i=1,select('#',...) do p[i]=tostring(select(i,...)) end table.insert(out,table.concat(p,'\t')) end
    local ok2, err = pcall(fn); print = old_print
    if not ok2 then print('  -> ' .. label .. ' 运行失败: ' .. tostring(err)); return false end
    print('  -> ' .. label .. ' 运行成功 (' .. #out .. ' 行)'); return true
end

save(bc, 'cur.luac')
print('初始 size=' .. #bc); test_run('初始')

-- str_encrypt
local p = load_proto('cur.luac'); str_enc.encrypt(p, {key=0x55}); save(luac.dump(p), 'cur.luac')
print('+str_encrypt'); test_run('+str_encrypt')

-- str_split
local p = load_proto('cur.luac'); str_split.obfuscate(p); save(luac.dump(p), 'cur.luac')
print('+str_split'); test_run('+str_split')

-- 检查 str_split 后的常量和指令
local p = load_proto('cur.luac')
print('  constants after str_split:')
for i = 1, math.min(25, #p.k) do
    print('    k['..i..']:', type(p.k[i]), tostring(p.k[i]))
end

-- const_shuffle (文件接口)
local const_shuffle = require('const_shuffle')
const_shuffle.shuffle('cur.luac', 'cur2.luac')
os.remove('cur.luac'); os.rename('cur2.luac', 'cur.luac')
print('+const_shuffle'); test_run('+const_shuffle')

-- instruction_mutate
local inst_mutate = require('instruction_mutate')
inst_mutate.process('cur.luac', 'cur2.luac')
os.remove('cur.luac'); os.rename('cur2.luac', 'cur.luac')
print('+instruction_mutate'); test_run('+inst_mutate')

-- opaque_predicate
local opaque_pred = require('opaque_predicate')
opaque_pred.process('cur.luac', 'cur2.luac')
os.remove('cur.luac'); os.rename('cur2.luac', 'cur.luac')
print('+opaque_predicate'); test_run('+opaque_pred')
