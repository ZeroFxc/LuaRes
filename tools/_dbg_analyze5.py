# -*- coding: utf-8 -*-
import re, sys, io

path = r'E:\LuaRes\1.log'
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# 找 top>3000 的行号
big_linenos = []
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    n = 0
    for line in f:
        n += 1
        m = re.search(r'top=(\d+)', line)
        if m and int(m.group(1)) > 3000:
            big_linenos.append(n)

print('big-top>3000 lines: %d' % len(big_linenos))
print('first=%d last=%d' % (big_linenos[0], big_linenos[-1]))
print('distinct line numbers (first 40):')
print(big_linenos[:40])

# 取第一个 big 行和最后一个 big 行的上下文
def ctx(center, half=12):
    out = []
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        for i, line in enumerate(f, 1):
            if center - half <= i <= center + half:
                out.append('%d| %s' % (i, line.rstrip('\n')[:160]))
            if i > center + half:
                break
    return out

print()
print('=== context around first big-top (line %d) ===' % big_linenos[0])
for c in ctx(big_linenos[0]):
    print(c)

print()
print('=== context around last big-top (line %d) ===' % big_linenos[-1])
for c in ctx(big_linenos[-1]):
    print(c)

# 错误点上下文：找 'Class not found' 的调用者上下文（往上找最近的 lua_callk/pushstring 之前的调用链）
print()
print('=== first "Class not found" context ===')
err_lineno = None
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    for i, line in enumerate(f, 1):
        if 'Class not found' in line:
            err_lineno = i
            break
for c in ctx(err_lineno, 16):
    print(c)

# 'Runtime error' 上下文
print()
print('=== first "Runtime error" context ===')
r_lineno = None
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    for i, line in enumerate(f, 1):
        if 'Runtime error' in line:
            r_lineno = i
            break
for c in ctx(r_lineno, 16):
    print(c)
