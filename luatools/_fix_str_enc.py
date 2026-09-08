p = r'E:\LuaRes\luaclib\str_encrypt.c'
s = open(p, encoding='utf-8').read()

old = '''    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TSHRSTR || p->k_tag[i] == LUA_TLNGSTR) && p->k_str[i]
            && p->k_str_len[i] > 0)
            str_idx[str_count++] = i;
    }'''

new = '''    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i] == LUA_TSHRSTR || p->k_tag[i] == LUA_TLNGSTR) && p->k_str[i]
            && p->k_str_len[i] > 1)  /* skip 1-byte strings (byte->char lookup table entries) */
            str_idx[str_count++] = i;
    }'''

s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('fixed')
