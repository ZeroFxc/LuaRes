#!/usr/bin/env python3
"""Register const_hide/deconst_hide in menu.lua"""
path = r'E:\LuaRes\luatools\menu.lua'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

changes = []

# 1. FORWARD_ORDER: add const_hide before str_encrypt
changes.append((
    "'bool_obfuscate', 'num_obfuscate', 'str_split', 'str_encrypt',",
    "'bool_obfuscate', 'num_obfuscate', 'str_split', 'const_hide', 'str_encrypt',"
))

# 2. FORWARD_DESC: add const_hide
changes.append((
    "    str_encrypt = '字符串加密(运行时解密)',",
    "    str_encrypt = '字符串加密(运行时解密)',\n    const_hide = '常量池隐藏(字符串合并blob)',"
))

# 3. REVERSE_ORDER: add deconst_hide after destr_encrypt
changes.append((
    "    'destr_split', 'destr_encrypt',",
    "    'destr_split', 'destr_encrypt', 'deconst_hide',"
))

# 4. REVERSE_DESC: add deconst_hide
changes.append((
    "    destr_encrypt = '还原字符串加密',",
    "    destr_encrypt = '还原字符串加密',\n    deconst_hide = '还原常量池隐藏',"
))

# 5. FORWARD_FN: add const_hide
changes.append((
    "    str_encrypt = 'encrypt',",
    "    str_encrypt = 'encrypt',\n    const_hide = 'process',"
))

# 6. REVERSE_FN: add deconst_hide
changes.append((
    "    destr_encrypt = 'clean',",
    "    destr_encrypt = 'clean',\n    deconst_hide = 'clean',"
))

failed = []
for i, (old, new) in enumerate(changes):
    if old in src:
        src = src.replace(old, new, 1)
    else:
        failed.append(i)

if failed:
    print(f"FAILED: {failed}")
    for i in failed:
        print(f"  --- change {i} ---")
        print(changes[i][0][:150])
else:
    print(f"All {len(changes)} changes applied")

with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
