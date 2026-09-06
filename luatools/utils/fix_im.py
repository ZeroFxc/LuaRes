p = r'E:\LuaRes\luaclib\instruction_mutate.c'
s = open(p, encoding='utf-8').read()

old = '''static int get_zero_const(luac_Proto *p) {
    for (int i = 0; i < p->sizek; i++) {
        if ((p->k_tag[i]==LUA_TNUMFLT||p->k_tag[i]==LUA_TNUMINT) && p->k_num[i]==0.0) return i;
    }
    return obf_add_k_number(p, 0.0);
}'''

new = '''static int get_zero_const(luac_Proto *p) {
    /* prefer integer 0 so identity ADD preserves integer type */
    for (int i = 0; i < p->sizek; i++) {
        if (p->k_tag[i] == LUA_TNUMINT && p->k_num[i] == 0.0) return i;
    }
    /* add integer zero constant */
    int idx = p->sizek;
    p->k_tag = realloc(p->k_tag, sizeof(int) * (p->sizek + 1));
    p->k_str = realloc(p->k_str, sizeof(char *) * (p->sizek + 1));
    p->k_str_len = realloc(p->k_str_len, sizeof(int) * (p->sizek + 1));
    p->k_num = realloc(p->k_num, sizeof(double) * (p->sizek + 1));
    p->k_bool = realloc(p->k_bool, sizeof(int) * (p->sizek + 1));
    p->k_tag[idx] = LUA_TNUMINT;
    p->k_str[idx] = NULL; p->k_str_len[idx] = 0;
    p->k_num[idx] = 0.0; p->k_bool[idx] = 0;
    p->sizek++;
    return idx;
}'''

if old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('fixed instruction_mutate zero const')
else:
    print('pattern not found')
