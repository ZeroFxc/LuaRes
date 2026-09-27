# -*- coding: utf-8 -*-
p = 'lua_State *L'
print("p.split()       =", p.split())
toks = " ".join(p.split()).split(" ")
print("toks            =", toks)
print("name            =", repr(toks[-1]))
print("type            =", repr(" ".join(toks[:-1])))

# 模拟实际读取的文件行
lines = open(r"E:\LuaRes\luasafe\lapi.c", encoding="utf-8", errors="replace").readlines()
for i, ln in enumerate(lines):
    if "lua_checkstack" in ln:
        print("line", i + 1, repr(ln))
        break
