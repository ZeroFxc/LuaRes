with open(r'E:\LuaRes\luatools\menu.lua', 'r', encoding='utf-8') as f:
    content = f.read()

old = """local function get_fn(mod, mode)
    if mode == 'reverse' then
        return mod.clean or mod.deobfuscate or mod.run or mod.strip or mod.process
    else
        return mod.encrypt or mod.obfuscate or mod.run or mod.protect
            or mod.shuffle or mod.process or mod.inject or mod.strip
    end
end"""

new = """-- 正向模块真实入口函数映射
local FORWARD_FN = {
    bool_obfuscate = 'obfuscate',
    num_obfuscate = 'obfuscate',
    str_split = 'obfuscate',
    str_encrypt = 'encrypt',
    const_shuffle = 'shuffle',
    instruction_mutate = 'process_function',
    opaque_predicate = 'process_function',
    const_poison = 'poison',
    opaque_junk = 'inject',
    junk_jmp = 'inject',
    junk_loadk = 'inject',
    junk_move = 'inject',
    op48_junk = 'inject',
    luac_obfuscate = 'obfuscate_proto',
    luac_flatten = 'flatten_proto',
    debug_strip = 'strip',
    antidec = 'protect',
}

-- 反向模块真实入口函数映射
local REVERSE_FN = {
    deop48 = 'clean',
    dejunk_jmp = 'clean',
    dejunk_loadk = 'clean',
    dejunk_move = 'clean',
    deopaque_junk = 'clean',
    deopaque_predicate = 'clean',
    deconst_shuffle = 'clean',
    deinstruction_mutate = 'clean',
    debool_obfuscate = 'clean',
    denum_obfuscate = 'clean',
    destr_split = 'clean',
    destr_encrypt = 'clean',
    deconst_poison = 'clean',
    deflatten = 'clean',
    dedebug_strip = 'clean',
    fix_antidec = 'clean',
    deprotect = 'clean',
    de_junk_obfuscate = 'clean',
    deobfuscate = 'run',
}

local function get_fn(name, mode)
    local map = (mode == 'reverse') and REVERSE_FN or FORWARD_FN
    local fn_name = map[name]
    if not fn_name then return nil end
    local mod = package.loaded[name]
    if not mod then return nil end
    return mod[fn_name]
end"""

if old in content:
    content = content.replace(old, new, 1)
    # 修改 execute 中 get_fn 的调用：get_fn(mod, mode) -> get_fn(name, mode)
    old2 = "local fn = get_fn(mod, mode)"
    new2 = "local fn = get_fn(name, mode)"
    content = content.replace(old2, new2, 1)
    with open(r'E:\LuaRes\luatools\menu.lua', 'w', encoding='utf-8') as f:
        f.write(content)
    print('OK')
else:
    print('NOT FOUND')
