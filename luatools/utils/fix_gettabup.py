#!/usr/bin/env python3
"""Fix GETTABUP false positive in destr_encrypt.lua:
verify GETUPVAL.A == GETTABLE.B before treating as GETTABUP pattern."""
path = r'E:\LuaRes\luatools\reverse\destr_encrypt.lua'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old = '''                                if getupval_pos then
                                    -- GETTABUP 模式: GETUPVAL + LOADK + 解密序列 + GETTABLE
                                    -- 还原为 GETTABUP ga, gu_b, loadk_const+256
                                    local gu_b = luac.GETARG_B(code[getupval_pos])
                                    local ga = luac.GETARG_A(code[gettable_pos])
                                    code[getupval_pos] = luac.CREATE_ABC(luac.OP_GETTABUP, ga, gu_b, loadk_const + 256)'''

new = '''                                if getupval_pos and luac.GETARG_A(code[getupval_pos]) == luac.GETARG_B(code[gettable_pos]) then
                                    -- GETTABUP 模式: GETUPVAL + LOADK + 解密序列 + GETTABLE
                                    -- 必须 GETUPVAL.A == GETTABLE.B (表寄存器匹配)
                                    -- 还原为 GETTABUP ga, gu_b, loadk_const+256
                                    local gu_b = luac.GETARG_B(code[getupval_pos])
                                    local ga = luac.GETARG_A(code[gettable_pos])
                                    code[getupval_pos] = luac.CREATE_ABC(luac.OP_GETTABUP, ga, gu_b, loadk_const + 256)'''

if old in src:
    src = src.replace(old, new, 1)
    print("GETTABUP guard added")
else:
    print("FAILED: pattern not found")
    idx = src.find('getupval_pos then')
    if idx >= 0:
        print(src[idx:idx+400])

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
