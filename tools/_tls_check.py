# -*- coding: utf-8 -*-
import re, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

path = r'E:\LuaRes\tools\tls_mt_test.log'
n = 0
bad = 0
ok_line = re.compile(r'^\[\d\d:\d\d:\d\d\]\[tid=\d+\] test_worker\(id=\d+, i=\d+, tag="hello\\"\\\\x"\)$')
nest_line = re.compile(r'^\[\d\d:\d\d:\d\d\]\[tid=\d+\]\s+nested\(inner="nest"\)$')
tid_map = {}
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.rstrip('\n')
        n += 1
        if ok_line.match(line) or nest_line.match(line):
            m = re.search(r'tid=(\d+)', line)
            tid_map.setdefault(m.group(1), 0)
            tid_map[m.group(1)] += 1
        else:
            bad += 1
            if bad <= 5:
                print('BAD line %d: %s' % (n, line[:160]))
print('total=%d bad=%d' % (n, bad))
print('per-tid counts: %s' % tid_map)
