#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成各种模块搭配的混淆字节码，打包成单个自测试 Lua 文件。
用法: python gen_combo_test.py
输出: combo_test.lua (用户在 andlua 上运行，把日志发回来)
"""
import subprocess
import os
import sys

LUASAFE_DIR = r"E:\LuaRes\luasafe"
LUA_EXE = os.path.join(LUASAFE_DIR, "lua_luac.exe")
INPUT_LUA = r"E:\LuaRes\boolean.lua"
OUTPUT_LUA = os.path.join(LUASAFE_DIR, "combo_test.lua")

# 模块搭配定义: (名称, 阶段列表)
# 阶段: ("proto", [(模块名, 函数名, 参数), ...]) 或 ("file", [(模块名, 函数名), ...])
# 标准顺序: 基础proto → 文件模块 → 垃圾proto → 控制流文件 → antidec
P_BOOL = ("bool_obfuscate", "obfuscate", None)
P_NUM = ("num_obfuscate", "obfuscate", None)
P_STR = ("str_split", "obfuscate", None)
P_POISON = ("const_poison", "poison", None)
P_OJ = ("opaque_junk", "inject", None)
P_JJ = ("junk_jmp", "inject", None)
P_JL = ("junk_loadk", "inject", None)
P_JM = ("junk_move", "inject", None)
P_OP48 = ("op48_junk", "inject", None)
P_ANTITD = ("antidec", "protect", None)
F_CS = ("const_shuffle", "shuffle")
F_IM = ("instruction_mutate", "process")
F_OP = ("opaque_predicate", "process")
F_LOB = ("luac_obfuscate", "obfuscate")
F_FLAT = ("luac_flatten", "flatten")
F_DBG = ("debug_strip", "strip")

COMBOS = [
    ("none", []),
    ("bool", [("proto", [P_BOOL])]),
    ("num", [("proto", [P_NUM])]),
    ("str_split", [("proto", [P_STR])]),
    ("bool+num", [("proto", [P_BOOL, P_NUM])]),
    ("bool+str", [("proto", [P_BOOL, P_STR])]),
    ("num+str", [("proto", [P_NUM, P_STR])]),
    ("bool+num+str", [("proto", [P_BOOL, P_NUM, P_STR])]),
    ("base6", [
        ("proto", [P_BOOL, P_NUM, P_STR]),
        ("file", [F_CS, F_IM, F_OP]),
    ]),
    ("base6+poison", [
        ("proto", [P_BOOL, P_NUM, P_STR]),
        ("file", [F_CS, F_IM, F_OP]),
        ("proto", [P_POISON]),
    ]),
    ("base+junk", [
        ("proto", [P_BOOL, P_NUM, P_STR]),
        ("file", [F_CS, F_IM, F_OP]),
        ("proto", [P_POISON, P_OJ, P_JJ, P_JL, P_JM, P_OP48]),
    ]),
    ("base+junk+cf", [
        ("proto", [P_BOOL, P_NUM, P_STR]),
        ("file", [F_CS, F_IM, F_OP]),
        ("proto", [P_POISON, P_OJ, P_JJ, P_JL, P_JM, P_OP48]),
        ("file", [F_LOB, F_FLAT]),
    ]),
    ("full_noantitd", [
        ("proto", [P_BOOL, P_NUM, P_STR]),
        ("file", [F_CS, F_IM, F_OP]),
        ("proto", [P_POISON, P_OJ, P_JJ, P_JL, P_JM, P_OP48]),
        ("file", [F_LOB, F_FLAT, F_DBG]),
    ]),
    ("full_all", [
        ("proto", [P_BOOL, P_NUM, P_STR]),
        ("file", [F_CS, F_IM, F_OP]),
        ("proto", [P_POISON, P_OJ, P_JJ, P_JL, P_JM, P_OP48]),
        ("file", [F_LOB, F_FLAT, F_DBG]),
        ("proto", [P_ANTITD]),
    ]),
    ("str_only+antitd", [
        ("proto", [P_STR, P_ANTITD]),
    ]),
    ("junk_only", [
        ("proto", [P_OJ, P_JJ, P_OP48]),
    ]),
    ("cf_only", [
        ("file", [F_LOB, F_FLAT]),
    ]),
    ("str+cf", [
        ("proto", [P_STR]),
        ("file", [F_LOB, F_FLAT]),
    ]),
    ("num+str+junk", [
        ("proto", [P_NUM, P_STR, P_OJ, P_JJ, P_OP48]),
    ]),
]


def gen_lua_script(combo_name, stages, input_path, output_path):
    """生成单个搭配的混淆 Lua 脚本（支持多轮 proto/file 交替）"""
    lines = []
    lines.append('local luac = require("luac")')
    lines.append('print = function() end')  # 禁用所有模块的 print 输出
    # 读取源码
    lines.append('local f = io.open("%s", "r")' % input_path.replace("\\", "/"))
    lines.append('local src = f:read("*a")')
    lines.append('f:close()')
    lines.append('local func = load(src)')
    lines.append('local bc = string.dec(string.dump(func))')
    lines.append('local proto = luac.undump(bc, false)')

    for stage_type, mods in stages:
        if stage_type == "proto":
            for mod_name, func_name, args in mods:
                lines.append('local m = require("%s")' % mod_name)
                if args:
                    lines.append('m.%s(proto, %s)' % (func_name, args))
                else:
                    lines.append('m.%s(proto)' % func_name)
        elif stage_type == "file":
            # dump 到临时文件
            lines.append('local ff = io.open("tmp_in.luac", "wb")')
            lines.append('ff:write(luac.dump(proto))')
            lines.append('ff:close()')
            for mod_name, func_name in mods:
                lines.append('local m = require("%s")' % mod_name)
                lines.append('m.%s("tmp_in.luac", "tmp_out.luac")' % func_name)
                lines.append('os.remove("tmp_in.luac")')
                lines.append('os.rename("tmp_out.luac", "tmp_in.luac")')
            # reload
            lines.append('local ff = io.open("tmp_in.luac", "rb")')
            lines.append('local data = ff:read("*a")')
            lines.append('ff:close()')
            lines.append('os.remove("tmp_in.luac")')
            lines.append('proto = luac.undump(data, false)')

    # 最终输出：用 andlua 格式编码
    lines.append('local final_bc = luac.dump(proto)')
    lines.append('local encoded = string.dump(load(final_bc))')
    lines.append('io.write(encoded)')

    return "\n".join(lines)


def bytes_to_lua_string(data):
    """把字节码转换成 Lua 转义字符串 (用十进制转义，避免 0 字节问题)"""
    parts = []
    for i, b in enumerate(data):
        if i % 20 == 0:
            parts.append('"\n  .."')
        parts.append("\\%d" % b)
    return "".join(parts)


def main():
    os.chdir(LUASAFE_DIR)

    results = {}  # name -> encoded_bytecode_string

    for combo_name, stages in COMBOS:
        print("Generating: %s ..." % combo_name, flush=True)

        script = gen_lua_script(combo_name, stages, INPUT_LUA, "out.luac")
        script_path = os.path.join(LUASAFE_DIR, "_gen_%s.lua" % combo_name.replace("+", "_"))
        with open(script_path, "w", encoding="utf-8") as f:
            f.write(script)

        try:
            proc = subprocess.run(
                [LUA_EXE, script_path],
                capture_output=True, timeout=60, cwd=LUASAFE_DIR
            )
            if proc.returncode != 0:
                print("  FAILED: %s" % proc.stderr.decode("utf-8", errors="replace")[:200])
                results[combo_name] = None
                continue
            encoded = proc.stdout
            if len(encoded) < 10:
                print("  FAILED: empty output")
                results[combo_name] = None
                continue
            # encoded 是 andlua string.dump 格式 (base64, '='开头)
            results[combo_name] = encoded.decode("latin-1")
            print("  OK: %d bytes (encoded)" % len(encoded))
        except Exception as e:
            print("  ERROR: %s" % e)
            results[combo_name] = None

        # 清理临时脚本
        if os.path.exists(script_path):
            os.remove(script_path)

    # 生成测试 Lua 文件
    print("\nGenerating combo_test.lua ...")
    lines = []
    lines.append("-- 自动生成的模块搭配测试文件")
    lines.append("-- 在 andlua 中运行，把输出日志发回")
    lines.append("")
    lines.append("local function run_test(name, encoded)")
    lines.append("  io.write(\"[TEST] \" .. name .. \" ... \")")
    lines.append("  local ok, data = pcall(string.dec, encoded)")
    lines.append("  if not ok then")
    lines.append("    print(\"DEC_FAIL: \" .. tostring(data))")
    lines.append("    return")
    lines.append("  end")
    lines.append("  local ok2, func = pcall(load, data)")
    lines.append("  if not ok2 then")
    lines.append("    print(\"LOAD_FAIL: \" .. tostring(func))")
    lines.append("    return")
    lines.append("  end")
    lines.append("  -- 捕获 print 输出")
    lines.append("  local old_print = print")
    lines.append("  local outputs = {}")
    lines.append("  print = function(...)")
    lines.append("    local p = {}")
    lines.append("    for i = 1, select('#', ...) do p[i] = tostring(select(i, ...)) end")
    lines.append("    table.insert(outputs, table.concat(p, \"\\t\"))")
    lines.append("  end")
    lines.append("  local ok3, err = pcall(func)")
    lines.append("  print = old_print")
    lines.append("  if not ok3 then")
    lines.append("    print(\"RUN_FAIL: \" .. tostring(err))")
    lines.append("  else")
    lines.append("    print(\"PASS (\" .. #outputs .. \" lines)\")")
    lines.append("  end")
    lines.append("end")
    lines.append("")
    lines.append("print(\"=== 模块搭配测试开始 ===\")")
    lines.append("print(\"时间: \" .. os.date())")
    lines.append("")

    for combo_name, encoded in results.items():
        if encoded is None:
            lines.append("-- %s: 生成失败，跳过" % combo_name)
            lines.append("print(\"[SKIP] %s (gen failed)\")" % combo_name)
        else:
            # 把 encoded 写成 Lua 字符串 (用长字符串或转义)
            # encoded 是 base64 文本，可以直接用引号
            safe_str = encoded.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
            lines.append('run_test("%s", "%s")' % (combo_name, safe_str))
        lines.append("")

    lines.append("print(\"=== 测试结束 ===\")")

    with open(OUTPUT_LUA, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print("Done: %s" % OUTPUT_LUA)
    print("Total combos: %d, success: %d" % (
        len(COMBOS),
        sum(1 for v in results.values() if v is not None)
    ))


if __name__ == "__main__":
    main()
