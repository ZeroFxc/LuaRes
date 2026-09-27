# -*- coding: utf-8 -*-
import re, collections, sys, io

path = r'E:\LuaRes\1.log'
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

line_re = re.compile(r'^\[(\d\d:\d\d:\d\d)\]\[tid=(\d+)\]\s+(.*)$')
corrupt_cnt = 0
corrupt_samp = []
# 损坏判定：行内出现第二个 '[HH:MM:SS]' 或第二个 'tid='，或 'L=' 缺失（如 '0=' / 'op=1' 模式），或同字段重复
pat_tail = re.compile(r'\[\d\d:\d\d:\d\d\]\[tid=\d+\]')
pat_L = re.compile(r'[ (]0=[0-9a-f]')
pat_dup = re.compile(r'frm=\d+.*frm=\d+')

n = 0
tops = []            # (lineno, top) 采样
first_big = None
main_tid = None
lua_call_params = []

with open(path, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.rstrip('\n')
        n += 1
        m = line_re.match(line)
        if not m:
            continue
        t, tid, body = m.groups()
        if main_tid is None:
            main_tid = tid
        bad = False
        if pat_tail.search(body):
            bad = True
        elif pat_L.search(body):
            bad = True
        elif pat_dup.search(body):
            bad = True
        if bad:
            corrupt_cnt += 1
            if len(corrupt_samp) < 12:
                corrupt_samp.append((n, t, tid, body[:200]))
        tm = re.search(r'top=(\d+)', body)
        if tm:
            v = int(tm.group(1))
            if v > 500 and first_big is None:
                first_big = (n, t, tid, body[:120])
            if n % 3000 == 0:
                tops.append((n, v))
        if body.startswith('LUA_CALL'):
            lua_call_params.append((n, body[:120]))

print('TOTAL_LINES=%d' % n)
print('CORRUPT_LINES=%d (%.4f%%)' % (corrupt_cnt, 100.0*corrupt_cnt/n))
print()
print('=== corrupt samples ===')
for s in corrupt_samp:
    print('line=%d %s tid=%s' % (s[0], s[1], s[2]))
    print('   ' + s[3])
print()
print('=== first top>500 ===')
print(first_big)
print()
print('=== top depth samples (every 3000 lines) first 40 ===')
for x in tops[:40]:
    print('line=%d top=%d' % x)
print('...')
print('=== top depth samples (every 3000 lines) last 20 ===')
for x in tops[-20:]:
    print('line=%d top=%d' % x)
print()
print('=== LUA_CALL lines (%d) ===' % len(lua_call_params))
for x in lua_call_params:
    print('line=%d %s' % x)
