#!/usr/bin/env python3
"""Add SELF pattern recognition to destr_encrypt.lua"""
path = r'E:\LuaRes\luatools\reverse\destr_encrypt.lua'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

# Add SELF check alongside GETTABLE check
old_gettable = '''                            -- 检查后面是否有 GETTABLE 使用 mv_dst 作为 key
                            local gettable_pos = nil
                            if i + 4 <= #code then
                                local next_op = luac.GET_OPCODE(code[i + 4])
                                if next_op == luac.OP_GETTABLE then
                                    local ga = luac.GETARG_A(code[i + 4])
                                    local gb = luac.GETARG_B(code[i + 4])
                                    local gc = luac.GETARG_C(code[i + 4])
                                    if gc == mv_dst then
                                        gettable_pos = i + 4
                                    end
                                end
                            end

                            if gettable_pos then'''

new_gettable = '''                            -- 检查后面是否有 GETTABLE 或 SELF 使用 mv_dst 作为 key
                            local gettable_pos = nil
                            local self_pos = nil
                            if i + 4 <= #code then
                                local next_op = luac.GET_OPCODE(code[i + 4])
                                if next_op == luac.OP_GETTABLE then
                                    local ga = luac.GETARG_A(code[i + 4])
                                    local gb = luac.GETARG_B(code[i + 4])
                                    local gc = luac.GETARG_C(code[i + 4])
                                    if gc == mv_dst then
                                        gettable_pos = i + 4
                                    end
                                elseif next_op == luac.OP_SELF then
                                    local sa = luac.GETARG_A(code[i + 4])
                                    local sb = luac.GETARG_B(code[i + 4])
                                    local sc = luac.GETARG_C(code[i + 4])
                                    if sc == mv_dst then
                                        self_pos = i + 4
                                    end
                                end
                            end

                            if self_pos then
                                -- SELF 模式: LOADK(加密键) + 解密序列 + SELF(寄存器键)
                                -- 还原为 SELF sa, sb, loadk_const+256 (常量键)
                                local sa = luac.GETARG_A(code[self_pos])
                                local sb = luac.GETARG_B(code[self_pos])
                                code[self_pos] = luac.CREATE_ABC(luac.OP_SELF, sa, sb, loadk_const + 256)
                                -- 删除 LOADK + CLOSURE + MOVE + CALL + MOVE
                                local remove_start = loadk_pos
                                local remove_count = self_pos - loadk_pos
                                for j = 1, remove_count do
                                    table.remove(code, remove_start)
                                end
                                adjust_jumps_remove(code, remove_start, remove_count)
                                count = count + 1
                                i = remove_start
                            elseif gettable_pos then'''

if old_gettable in src:
    src = src.replace(old_gettable, new_gettable, 1)
    print("SELF pattern added successfully")
else:
    print("FAILED: could not find gettable pattern")
    # Debug: show what's around that area
    idx = src.find('gettable_pos')
    if idx >= 0:
        print(src[idx-50:idx+300])

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
