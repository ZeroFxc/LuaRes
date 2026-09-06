p = r'E:\LuaRes\luaclib\obf_util.c'
s = open(p, encoding='utf-8').read()

old_func = '''void obf_adjust_jumps_remove(unsigned int *code, int code_len, int pos, int n) {
    int pos0 = pos - 1;
    for (int i = 0; i < code_len; i++) {
        if (is_jump_op(code[i] & 0x3F)) {
            int sbx = (int)(code[i] >> 14) - 131071;
            int target = i + sbx + 1;
            int delta = 0;
            if (i < pos0 && target > pos0) delta = -n;
            else if (i >= pos0 && target < pos0) delta = n;
            if (delta) code[i] = (code[i] & 0x3FFF) | ((unsigned int)(sbx + delta + 131071) << 14);
        }
    }
}'''

new_func = '''void obf_adjust_jumps_remove(unsigned int *code, int code_len, int pos, int n) {
    int pos0 = pos - 1;
    for (int i = 0; i < code_len; i++) {
        if (is_jump_op(code[i] & 0x3F)) {
            int sbx = (int)(code[i] >> 14) - 131071;
            /* compute OLD index before removal: jumps at/after pos0 were at i+n */
            int old_i = (i >= pos0) ? i + n : i;
            int target_old = old_i + sbx + 1;
            int delta = 0;
            if (old_i < pos0 && target_old > pos0) delta = -n;
            else if (old_i > pos0 && target_old < pos0) delta = n;
            if (delta) code[i] = (code[i] & 0x3FFF) | ((unsigned int)(sbx + delta + 131071) << 14);
        }
    }
}'''

if old_func in s:
    s = s.replace(old_func, new_func, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('fixed remove function')
else:
    print('remove pattern not found')
