p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
s = open(p, encoding='utf-8').read()
old = '''if (target_idx < 0 || target_idx >= n)
#if OBF_DEBUG
                fprintf(stderr, "[OBF-PRE] idx=%d op=%d old_sbx=%d target_idx=%d n=%d\\n", i, op, old_sbx, target_idx, n);
#endif
            int new_target_pos;'''
new = '''if (target_idx < 0 || target_idx >= n) {
#if OBF_DEBUG
                fprintf(stderr, "[OBF-PRE] idx=%d op=%d old_sbx=%d target_idx=%d n=%d\\n", i, op, old_sbx, target_idx, n);
#endif
            }
            int new_target_pos;'''
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
