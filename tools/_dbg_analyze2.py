# -*- coding: utf-8 -*-
import re, collections, sys, io

path = r'E:\LuaRes\1.log'
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

line_re = re.compile(r'^\[(\d\d:\d\d:\d\d)\]\[tid=(\d+)\]\s+(.*)$')
sec_cnt = collections.Counter()
frm_cnt = collections.Counter()
bigtop = []          # top>500 的行
classnot = []        # Class not found 上下文
msgerr = []          # Runtime error 上下文
version_null = []    # lua_version L=(null) 上下文
trunc = []           # 被截断的字符串（含 ... 且 len 较大）
tail = collections.deque(maxlen=120)
last_sec = None
last_lines = collections.deque(maxlen=8)

with open(path, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.rstrip('\n')
        tail.append(line)
        m = line_re.match(line)
        if not m:
            continue
        t, tid, body = m.groups()
        sec_cnt[t[:5]] += 1
        fm = re.search(r'frm=(\d+)', body)
        if fm:
            frm_cnt[int(fm.group(1))] += 1
        tm = re.search(r'top=(\d+)', body)
        if tm and int(tm.group(1)) > 500:
            bigtop.append((t, body[:150]))
        if 'Class not found' in body:
            classnot.append((t, body[:120]))
        if 'Runtime error' in body or 'attempt to perform arithmetic' in body:
            msgerr.append((t, body[:160]))
        if body.startswith('lua_version') and 'L=(null)' in body:
            version_null.append((t, body[:120]))
        if '...' in body and ('len=' in body or 's=' in body):
            mm = re.search(r'len=(\d+)', body)
            if mm and int(mm.group(1)) > 130:
                trunc.append((t, body[:120]))

print('=== lines per 5-sec bucket (first 30) ===')
for k, v in sorted(sec_cnt.items())[:30]:
    print('%s  %8d' % (k, v))
print('...')
print('=== lines per 5-sec bucket (last 10) ===')
for k, v in sorted(sec_cnt.items())[-10:]:
    print('%s  %8d' % (k, v))
print('buckets=%d' % len(sec_cnt))
print()
print('=== frm distribution ===')
for k in sorted(frm_cnt):
    print('frm=%2d  %8d' % (k, frm_cnt[k]))
print()
print('=== big top>500 lines: %d, first 15 ===' % len(bigtop))
for x in bigtop[:15]:
    print(x[0], x[1])
print()
print('=== Class not found occurrences: %d, first 8 ===' % len(classnot))
for x in classnot[:8]:
    print(x[0], x[1])
print()
print('=== Runtime error occurrences: %d, first 10 ===' % len(msgerr))
for x in msgerr[:10]:
    print(x[0], x[1])
print()
print('=== lua_version L=(null): %d, first 6 ===' % len(version_null))
for x in version_null[:6]:
    print(x[0], x[1])
print()
print('=== truncated long strings >130: %d, first 12 ===' % len(trunc))
for x in trunc[:12]:
    print(x[0], x[1])
print()
print('=== TAIL 40 ===')
for tline in tail:
    print(tline)
