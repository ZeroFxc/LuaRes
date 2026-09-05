#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成自包含单测试文件（开启内置字符串加密版本）"""
import subprocess
import os

LUASAFE_DIR = r"E:\LuaRes\luasafe"
LUA_EXE = os.path.join(LUASAFE_DIR, "lua_luac.exe")
INPUT_LUA = r"E:\LuaRes\boolean.lua"
OUTPUT_LUA = os.path.join(LUASAFE_DIR, "single_test.lua")

def gen_encoded(src_lua, obfuscate_script):
    """生成编码后的字节码字符串"""
    script = f'''
local luac = require("luac")
print = function() end
local src = io.open("{src_lua.replace(chr(92), '/')}", "r"):read("*a")
local func = load(src)
local bc = string.dec(string.dump(func))
local proto = luac.undump(bc, false)
{obfuscate_script}
local enc = luac.dump(proto)
io.write(string.dump(load(enc)))
'''
    script_path = os.path.join(LUASAFE_DIR, "_gen_single.lua")
    with open(script_path, "w", encoding="utf-8") as f:
        f.write(script)
    proc = subprocess.run([LUA_EXE, script_path], capture_output=True, cwd=LUASAFE_DIR)
    if os.path.exists(script_path):
        os.remove(script_path)
    if proc.returncode != 0:
        print("FAIL:", proc.stderr.decode("utf-8", errors="replace")[:300])
        return None
    return proc.stdout.decode("latin-1")

# 测试用例
tests = [
    ("original", ""),
    ("str_encrypt_xor", """
require('str_encrypt').encrypt(proto, {key=0x55})
"""),
    ("str_split_pure_insn", """
require('str_split').obfuscate(proto)
"""),
    ("num_obfuscate", """
require('num_obfuscate').obfuscate(proto)
"""),
    ("bool_obfuscate", """
require('bool_obfuscate').obfuscate(proto)
"""),
    ("full_all_modules", """
require('bool_obfuscate').obfuscate(proto)
require('num_obfuscate').obfuscate(proto)
require('str_split').obfuscate(proto)
local f = io.open("tmp.luac","wb"); f:write(luac.dump(proto)); f:close()
require('const_shuffle').shuffle("tmp.luac","tmp2.luac"); os.remove("tmp.luac"); os.rename("tmp2.luac","tmp.luac")
require('instruction_mutate').process("tmp.luac","tmp2.luac"); os.remove("tmp.luac"); os.rename("tmp2.luac","tmp.luac")
require('opaque_predicate').process("tmp.luac","tmp2.luac"); os.remove("tmp.luac"); os.rename("tmp2.luac","tmp.luac")
local f2 = io.open("tmp.luac","rb"); local d = f2:read("*a"); f2:close(); os.remove("tmp.luac")
proto = luac.undump(d, false)
require('const_poison').poison(proto)
require('opaque_junk').inject(proto)
require('junk_jmp').inject(proto)
require('junk_loadk').inject(proto)
require('junk_move').inject(proto)
require('op48_junk').inject(proto)
local f3 = io.open("tmp.luac","wb"); f3:write(luac.dump(proto)); f3:close()
require('luac_obfuscate').obfuscate("tmp.luac","tmp2.luac"); os.remove("tmp.luac"); os.rename("tmp2.luac","tmp.luac")
require('luac_flatten').flatten("tmp.luac","tmp2.luac"); os.remove("tmp.luac"); os.rename("tmp2.luac","tmp.luac")
require('debug_strip').strip("tmp.luac","tmp2.luac"); os.remove("tmp.luac"); os.rename("tmp2.luac","tmp.luac")
local f4 = io.open("tmp.luac","rb"); local d2 = f4:read("*a"); f4:close(); os.remove("tmp.luac")
proto = luac.undump(d2, false)
require('anti_td').protect(proto)
"""),
]

results = {}
for name, obf_script in tests:
    print(f"Generating: {name} ...", flush=True)
    encoded = gen_encoded(INPUT_LUA, obf_script)
    if encoded:
        results[name] = encoded
        print(f"  OK: {len(encoded)} bytes")
    else:
        print(f"  FAILED")

# 生成自包含测试文件
lines = []
lines.append("-- 自包含单测试文件（开启内置字符串加密）")
lines.append("-- 在 andlua 中直接运行")
lines.append("")
lines.append("local function run_test(name, encoded)")
lines.append("  io.write(\"[TEST] \" .. name .. \" ... \")")
lines.append("  local ok, data = pcall(string.dec, encoded)")
lines.append("  if not ok then print(\"DEC_FAIL: \" .. tostring(data)); return end")
lines.append("  local ok2, func = pcall(load, data)")
lines.append("  if not ok2 then print(\"LOAD_FAIL: \" .. tostring(func)); return end")
lines.append("  local old_print = print; local outputs = {}")
lines.append("  print = function(...) local p={} for i=1,select('#',...) do p[i]=tostring(select(i,...)) end table.insert(outputs,table.concat(p,'\\t')) end")
lines.append("  local ok3, err = pcall(func); print = old_print")
lines.append("  if not ok3 then print(\"RUN_FAIL: \" .. tostring(err))")
lines.append("  else print(\"PASS (\" .. #outputs .. \" lines)\") end")
lines.append("end")
lines.append("")
lines.append("print(\"=== 单测试开始 (内置加密开启) ===\")")
lines.append("print(\"时间: \" .. os.date())")
lines.append("")

for name, encoded in results.items():
    safe = encoded.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    lines.append(f'run_test("{name}", "{safe}")')
    lines.append("")

lines.append("print(\"=== 测试结束 ===\")")

with open(OUTPUT_LUA, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"\nDone: {OUTPUT_LUA}")
print(f"Total tests: {len(results)}")
