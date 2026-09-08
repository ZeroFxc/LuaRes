p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Test: only add proto to p array, don't replace instructions
old = '''        /* 在原位置替换 */
        int delta = replace_count - block_len;
        if (delta > 0) {
            p->code = realloc(p->code, sizeof(unsigned int) * (p->sizecode + delta));
            memmove(&p->code[start + replace_count], &p->code[end],
                    sizeof(unsigned int) * (p->sizecode - end));
        } else if (delta < 0) {
            memmove(&p->code[start + replace_count], &p->code[end],
                    sizeof(unsigned int) * (p->sizecode - end));
        }
        memcpy(&p->code[start], replace, sizeof(unsigned int) * replace_count);
        p->sizecode += delta;
        free(replace);

        /* 修正 JMP 偏移 */
        if (delta != 0)
            obf_adjust_jumps_insert(p->code, p->sizecode, start + 1, delta);

        changed++;
        pos = start + replace_count + 1;  /* 跳过替换区域继续找 */'''

new = '''        /* DEBUG: only add proto, don't replace instructions */
        free(replace);
        changed++;
        pos = end + 1;
        (void)replace_count; (void)start; (void)end;'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('proto-only test mode')
