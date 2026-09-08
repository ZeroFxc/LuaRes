p = r'E:\LuaRes\luaclib\upvalue_promote.c'
s = open(p, encoding='utf-8').read()

# Restore the replacement code but skip JMP adjustment
old = '''        /* DEBUG: only add proto, don't replace instructions */
        free(replace);
        changed++;
        pos = end + 1;
        (void)replace_count; (void)start; (void)end;'''

new = '''        /* 在原位置替换 */
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

        /* DEBUG: skip JMP adjustment */
        changed++;
        pos = start + replace_count + 1;'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('replacement without JMP adjustment')
