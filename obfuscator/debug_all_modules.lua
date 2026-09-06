-- 逐步排查哪个模块导致运行失败
local luac = require('luac')

local input = '../boolean.lua'
local func = load(io.open(input):read('*a'))
local bc = string.dec(string.dump(func))

local function save(data, name)
    local f = io.open(name, 'wb')
    f:write(data)
    f:close()
end

local function load_proto(name)
    local f = io.open(name, 'rb')
    local data = f:read('*a')
    f:close()
    return luac.undump(data, false)
end

local function run_proto(name, mod_name, func_name, args)
    local mod = require(mod_name)
    local proto = load_proto('cur.luac')
    if args then mod[func_name](proto, args) else mod[func_name](proto) end
    save(luac.dump(proto), 'cur.luac')
    print(string.format('  %-20s code=%d k=%d', name, #proto.code, #proto.k))
end

local function run_file(name, mod_name, func_name)
    local mod = require(mod_name)
    mod[func_name]('cur.luac', 'cur2.luac')
    os.remove('cur.luac')
    os.rename('cur2.luac', 'cur.luac')
    local f = io.open('cur.luac', 'rb')
    local size = f:seek('end')
    f:close()
    print(string.format('  %-20s size=%d', name, size))
end

local function test_run(label)
    local f = io.open('cur.luac', 'rb')
    local data = f:read('*a')
    f:close()
    local ok, fn = pcall(load, data)
    if not ok then print('  -> ' .. label .. ' 加载失败: ' .. tostring(fn)); return false end
    local old_print = print
    local out = {}
    print = function(...) local p={} for i=1,select('#',...) do p[i]=tostring(select(i,...)) end table.insert(out,table.concat(p,'\t')) end
    local ok2, err = pcall(fn)
    print = old_print
    if not ok2 then print('  -> ' .. label .. ' 运行失败: ' .. tostring(err)); return false end
    print('  -> ' .. label .. ' 运行成功 (' .. #out .. ' 行输出)')
    return true
end

save(bc, 'cur.luac')
print('初始 size=' .. #bc)
test_run('初始')

print('\n=== 逐步添加 ===')
run_proto('bool_obfuscate', 'bool_obfuscate', 'obfuscate')
test_run('+bool')
run_proto('num_obfuscate', 'num_obfuscate', 'obfuscate')
test_run('+num')
run_proto('str_encrypt', 'str_encrypt', 'encrypt', {key=0x55})
test_run('+str')
run_file('const_shuffle', 'const_shuffle', 'shuffle')
test_run('+const_shuffle')
run_file('instruction_mutate', 'instruction_mutate', 'process')
test_run('+inst_mutate')
run_file('opaque_predicate', 'opaque_predicate', 'process')
test_run('+opaque_pred')
run_proto('const_poison', 'const_poison', 'poison')
test_run('+const_poison')
run_proto('opaque_junk', 'opaque_junk', 'inject')
test_run('+opaque_junk')
run_proto('junk_jmp', 'junk_jmp', 'inject')
test_run('+junk_jmp')
run_proto('junk_loadk', 'junk_loadk', 'inject')
test_run('+junk_loadk')
run_proto('junk_move', 'junk_move', 'inject')
test_run('+junk_move')
run_proto('op48_junk', 'op48_junk', 'inject')
test_run('+op48')
run_file('luac_obfuscate', 'luac_obfuscate', 'obfuscate')
test_run('+luac_obf')
run_file('luac_flatten', 'luac_flatten', 'flatten')
test_run('+flatten')
run_file('debug_strip', 'debug_strip', 'strip')
test_run('+debug_strip')
run_proto('antidec', 'antidec', 'protect')
test_run('+antidec')
