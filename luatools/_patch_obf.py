p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
s = open(p, encoding='utf-8').read()
old = '''        /* fixup iAsBx before emitting */
        if (IS_ASBX(op)) {
            int old_sbx = (int)(inst >> 14) - 131071;
            int target_idx = i + old_sbx + 1;'''
new = '''        /* fixup iAsBx before emitting */
        if (IS_ASBX(op)) {
            int old_sbx = (int)(inst >> 14) - 131071;
            int target_idx = i + old_sbx + 1;
            if (target_idx < 0 || target_idx >= n)
                fprintf(stderr, "[OBF-PRE] idx=%d op=%d old_sbx=%d target_idx=%d n=%d\\n", i, op, old_sbx, target_idx, n);'''
if old in s:
    s = s.replace(old, new)
    open(p, 'w', encoding='utf-8').write(s)
    print('ADDED DEBUG')
else:
    print('NOT FOUND')
