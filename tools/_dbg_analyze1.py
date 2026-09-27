# -*- coding: utf-8 -*-
import re, collections, sys, io

path = r'E:\LuaRes\1.log'
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

fn_cnt = collections.Counter()        # 函数名计数（去掉参数部分）
call_cnt = collections.Counter()      # LUA_CALL 的 name 统计
msg_lines = []                        # $(msg= 标记行
err_lines = []                        # 可疑错误行
null_lines = collections.Counter()    # L=(null) 的函数
times = []
tail = collections.deque(maxlen=60)

line_re = re.compile(r'^\[(\d\d:\d\d:\d\d)\]\[tid=(\d+)\]\s+(.*)$')
fn_re = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\(.*')

n = 0
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.rstrip('\n')
        n += 1
        m = line_re.match(line)
        if not m:
            if n < 200:
                print('NONSTD@%d: %r' % (n, line[:160]))
            continue
        t, tid, body = m.groups()
        times.append(t)
        if body.startswith('LUA_CALL'):
            mm = re.match(r'LUA_CALL name="([^"]*)" type=([CL]) nargs=(\d+) frm=(\d+)', body)
            if mm:
                call_cnt[(mm.group(1), mm.group(2))] += 1
            else:
                call_cnt[('RAW', body[:80])] += 1
            continue
        if body.startswith('$('):
            msg_lines.append(body)
            continue
        if body.startswith('luaV_'):
            fn_re2 = re.match(r'^(luaV_\w+)\(', body)
            if fn_re2: fn_cnt['luaV_' + fn_re2.group(1).split('_',1)[1]] += 1
            if 'L=(null)' in body:
                null_lines['luaV_' + body.split('(')[0]] += 1
            continue
        fm = fn_re.match(body)
        if fm:
            fn_cnt[fm.group(1)] += 1
            if 'L=(null)' in body and not fm.group(1).startswith('luaV_equalobj'):
                null_lines[fm.group(1)] += 1
        low = body.lower()
        if any(k in low for k in ('error', 'exception', 'cannot', 'failed', 'not found', 'attempt to', 'invalid', 'out of memory', 'segfault', 'stack overflow')):
            err_lines.append(body[:200])

print('TOTAL_LINES=%d' % n)
print('TIME_RANGE=%s .. %s' % (times[0] if times else '-', times[-1] if times else '-'))
print()
print('=== TOP 40 API by count ===')
for k, v in fn_cnt.most_common(40):
    print('%6d  %s' % (v, k))
print()
print('=== LUA_CALL by (name,type) top 25 ===')
for (name, tp), v in call_cnt.most_common(25):
    print('%6d  name=%s type=%s' % (v, name, tp))
print('LUA_CALL total=%d' % sum(call_cnt.values()))
print()
print('=== L=(null) abnormal (excluding luaV_equalobj) ===')
for k, v in null_lines.most_common(20):
    print('%6d  %s' % (v, k))
print()
print('=== suspicious error lines (%d) first 30 ===' % len(err_lines))
for e in err_lines[:30]:
    print(e)
print()
print('=== $(msg=...) markers (%d) ===' % len(msg_lines))
for mline in msg_lines:
    print(mline)
print()
print('=== TAIL 40 ===')
for tline in tail:
    print(tline)
