p = r'E:\LuaRes\luaclib\obf_util.c'
s = open(p, encoding='utf-8').read()
# Fix insert: target > pos0 -> target >= pos0 (instruction at insertion point shifts)
old1 = 'if (i < pos0 && target > pos0) delta = n;\n            else if (i >= pos0 && target < pos0) delta = -n;\n            if (delta) code[i] = (code[i] & 0x3FFF) | ((unsigned int)(sbx + delta + 131071) << 14);\n        }\n    }\n}\n\nvoid obf_adjust_jumps_remove'
new1 = 'if (i < pos0 && target >= pos0) delta = n;\n            else if (i >= pos0 && target < pos0) delta = -n;\n            if (delta) code[i] = (code[i] & 0x3FFF) | ((unsigned int)(sbx + delta + 131071) << 14);\n        }\n    }\n}\n\nvoid obf_adjust_jumps_remove'
if old1 in s:
    s = s.replace(old1, new1, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('fixed insert')
else:
    print('insert pattern not found')
