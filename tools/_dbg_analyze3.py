# -*- coding: utf-8 -*-
import re, collections, sys, io

path = r'E:\LuaRes\1.log'
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

line_re = re.compile(r'^\[(\d\d:\d\d:\d\d)\]\[tid=(\d+)\]\s+(.*)$')
sec_cnt = collections.Counter()     # 精确到秒
tid_cnt = collections.Counter()
bad_lines = []                       # 正则不匹配的行
corrupt = []                         # 行内含多个 'L=' 或明显交织
top_trace = []                       # top 深度序列采样
deep_start = None                    # top>500 首次出现行号
lua_call_pos = []
frm1_sec = collections.Counter()
last_500_lines = collections.deque(maxlen=500)

n = 0
top_series = []
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.rstrip('\n')
        n += 1
        m = line_re.match(line)
        if not m:
            if n < 5000:
                bad_lines.append((n, line[:200]))
            continue
        t, tid, body = m.groups()
        sec_cnt[t] += 1
        tid_cnt[tid] += 1
        if body.count('L=') > 1 or ('0=' in body and 'L=0' not in body) or 'frm=2' in body and 'frm=2' in body.replace('frm=2','',1):
            if len(corrupt) < 40:
                corrupt.append((n, t, body[:180]))
        tm = re.search(r'top=(\d+)', body)
        if tm:
            v = int(tm.group(1))
            if v > 500 and deep_start is None:
                deep_start = (n, t, body[:120])
            top_series.append((n, v))
        if body.startswith('LUA_CALL'):
            lua_call_pos.append((n, t, body[:100]))
        last_500_lines.append((n, t, body[:150]))

# 栈深度采样：每 20000 行取一个
print('=== top depth every 20000 lines ===')
step = 20000
for i in range(0, len(top_series), step):
    n_i, v = top_series[i]
    print('line=%7d top=%d' % (n_i, v))
print('deep_start(first top>500)=%s line=%d' % (deep_start[1] if deep_start else '-', deep_start[0] if deep_start else -1))
print('max_top=%d' % max((v for _, v in top_series), default=-1))

print()
print('=== per-second line count ===')
for k in sorted(sec_cnt):
    print('%s  %8d' % (k, sec_cnt[k]))

print()
print('=== tid distribution ===')
for k, v in tid_cnt.most_common():
    print('%s  %8d' % (k, v))

print()
print('=== LUA_CALL positions (%d) ===' % len(lua_call_pos))
for x in lua_call_pos:
    print(x)

print()
print('=== corrupt/interleaved lines (%d shown) ===' % len(corrupt))
for c in corrupt:
    print('line=%d %s %s' % (c[0], c[1], c[2]))

print()
print('=== bad-format lines (%d shown) ===' % len(bad_lines))
for b in bad_lines[:10]:
    print('line=%d %r' % b)

print()
print('=== LAST 30 lines of file ===')
for x in list(last_500_lines)[-30:]:
    print('line=%d %s %s' % x)
