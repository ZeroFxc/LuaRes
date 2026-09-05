-- 全模块混淆处理脚本（文件传递版）
local luac = require('luac')

local input = arg[1] or '../boolean.lua'
local output = arg[2] or 'boolean_obf.luac'

-- 读取源码并编译为字节码
local f = io.open(input, 'r')
local src = f:read('*a')
f:close()
local func = load(src)
local bc = string.dec(string.dump(func))

-- 写入初始字节码文件
local tmp_in = 'tmp_obf_in.luac'
local fout = io.open(tmp_in, 'wb')
fout:write(bc)
fout:close()

print('原始字节码大小:', #bc)

-- 定义所有 pass（文件路径接口）
-- 每个 pass: {name, module, func_name}
local file_passes = {
    {'const_shuffle', 'const_shuffle', 'shuffle'},
    {'instruction_mutate', 'instruction_mutate', 'process'},
    {'opaque_predicate', 'opaque_predicate', 'process'},
    {'luac_obfuscate', 'luac_obfuscate', 'obfuscate'},
    {'luac_flatten', 'luac_flatten', 'flatten'},
    {'debug_strip', 'debug_strip', 'strip'},
}

-- 定义 proto 接口的 pass（需要 undump/dump 包装）
local proto_passes = {
    {'bool_obfuscate', 'bool_obfuscate', 'obfuscate'},
    {'num_obfuscate', 'num_obfuscate', 'obfuscate'},
    {'str_encrypt', 'str_encrypt', 'encrypt', {key=0x55}},
    {'const_poison', 'const_poison', 'poison'},
    {'opaque_junk', 'opaque_junk', 'inject'},
    {'junk_jmp', 'junk_jmp', 'inject'},
    {'junk_loadk', 'junk_loadk', 'inject'},
    {'junk_move', 'junk_move', 'inject'},
    {'op48_junk', 'op48_junk', 'inject'},
    {'anti_td', 'anti_td', 'protect'},
}

local function run_file_pass(name, mod_name, func_name)
    local mod = require(mod_name)
    local fn = mod[func_name]
    if not fn then
        print(string.format('  [SKIP] %-20s no function %s', name, func_name))
        return false
    end
    local tmp_out = 'tmp_obf_out.luac'
    local ok, err = pcall(fn, tmp_in, tmp_out)
    if not ok then
        print(string.format('  [FAIL] %-20s %s', name, tostring(err)))
        return false
    end
    -- 交换文件
    os.remove(tmp_in)
    os.rename(tmp_out, tmp_in)
    -- 读取大小
    local f = io.open(tmp_in, 'rb')
    local size = f:seek('end')
    f:close()
    print(string.format('  [OK]   %-20s size=%d', name, size))
    return true
end

local function run_proto_pass(name, mod_name, func_name, args)
    local mod = require(mod_name)
    local fn = mod[func_name]
    if not fn then
        print(string.format('  [SKIP] %-20s no function %s', name, func_name))
        return false
    end
    -- undump
    local f = io.open(tmp_in, 'rb')
    local data = f:read('*a')
    f:close()
    local proto = luac.undump(data, false)
    -- 处理
    local ok, err
    if args then
        ok, err = pcall(fn, proto, args)
    else
        ok, err = pcall(fn, proto)
    end
    if not ok then
        print(string.format('  [FAIL] %-20s %s', name, tostring(err)))
        return false
    end
    -- dump
    local enc = luac.dump(proto)
    local fout = io.open(tmp_in, 'wb')
    fout:write(enc)
    fout:close()
    print(string.format('  [OK]   %-20s size=%d code=%d k=%d', name, #enc, #proto.code, #proto.k))
    return true
end

-- 按顺序执行：先 proto 级别的基础混淆，再文件级别的复杂混淆，最后 anti_td
print()
print('=== 第一阶段：基础混淆（proto接口）===')
run_proto_pass('bool_obfuscate', 'bool_obfuscate', 'obfuscate')
run_proto_pass('num_obfuscate', 'num_obfuscate', 'obfuscate')
run_proto_pass('str_encrypt', 'str_encrypt', 'encrypt', {key=0x55})

print()
print('=== 第二阶段：常量与指令（文件接口）===')
run_file_pass('const_shuffle', 'const_shuffle', 'shuffle')
run_file_pass('instruction_mutate', 'instruction_mutate', 'process')
run_file_pass('opaque_predicate', 'opaque_predicate', 'process')

print()
print('=== 第三阶段：proto接口垃圾指令 ===')
run_proto_pass('const_poison', 'const_poison', 'poison')
run_proto_pass('opaque_junk', 'opaque_junk', 'inject')
run_proto_pass('junk_jmp', 'junk_jmp', 'inject')
run_proto_pass('junk_loadk', 'junk_loadk', 'inject')
run_proto_pass('junk_move', 'junk_move', 'inject')
run_proto_pass('op48_junk', 'op48_junk', 'inject')

print()
print('=== 第四阶段：文件接口控制流 ===')
run_file_pass('luac_obfuscate', 'luac_obfuscate', 'obfuscate')
run_file_pass('luac_flatten', 'luac_flatten', 'flatten')
run_file_pass('debug_strip', 'debug_strip', 'strip')

print()
print('=== 第五阶段：防TD ===')
run_proto_pass('anti_td', 'anti_td', 'protect')

-- 复制到输出
os.remove(output)
os.rename(tmp_in, output)

-- 读取最终大小
local f = io.open(output, 'rb')
local final_size = f:seek('end')
f:close()

print()
print('最终字节码大小:', final_size)
print('膨胀率:', string.format('%.1f%%', (final_size / #bc - 1) * 100))
print('输出文件:', output)

-- 验证可运行
print()
print('=== 验证运行 ===')
local f = io.open(output, 'rb')
local final_bc = f:read('*a')
f:close()
local ok2, f2 = pcall(load, final_bc)
if not ok2 then
    print('加载失败:', f2)
else
    -- 捕获输出
    local old_print = print
    local outputs = {}
    print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do
            parts[i] = tostring(select(i, ...))
        end
        table.insert(outputs, table.concat(parts, '\t'))
    end
    local ok3, err = pcall(f2)
    print = old_print
    if not ok3 then
        print('运行失败:', err)
    else
        print('运行成功，输出:')
        for _, line in ipairs(outputs) do
            print('  ' .. line)
        end
    end
end
