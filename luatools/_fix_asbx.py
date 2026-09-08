p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
c = open(p, encoding='utf-8').read()

old = """        /* fixup iAsBx before emitting */
        if (IS_ASBX(op)) {
            int old_sbx = (int)(inst >> 14) - 131071;
            int target_idx = i + old_sbx + 1;
            if (target_idx >= 0 && target_idx < n) {
                int new_target_pos = group_start[target_idx];
                int new_current_pos = group_start[i];
                int new_sbx = new_target_pos - new_current_pos - 1;
                inst = LUAC_AsBx(op, (inst >> 6) & 0xFF, new_sbx);
            }
        }"""

new = """        /* fixup iAsBx before emitting */
        if (IS_ASBX(op)) {
            int old_sbx = (int)(inst >> 14) - 131071;
            int target_idx = i + old_sbx + 1;
            int new_target_pos;
            if (target_idx < 0) new_target_pos = 0;
            else if (target_idx >= n) new_target_pos = total; /* past end = return */
            else new_target_pos = group_start[target_idx];
            int new_current_pos = group_start[i];
            int new_sbx = new_target_pos - new_current_pos - 1;
            inst = LUAC_AsBx(op, (inst >> 6) & 0xFF, new_sbx);
        }"""

assert old in c, 'pattern not found'
c = c.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(c)
print('OK')
