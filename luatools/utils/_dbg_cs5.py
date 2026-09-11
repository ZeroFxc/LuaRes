path = r'E:\LuaRes\luaclib\const_shuffle.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old = '''    obf_invalidate_all_caches(L, p);
    fprintf(stderr, "[cs] invalidate done\\n");
    obf_srand((unsigned int)time(NULL));
    shuffle_function(p);
    fprintf(stderr, "[cs] shuffle done\\n");'''

new = '''    obf_invalidate_all_caches(L, p);
    fflush(stderr);
    fprintf(stderr, "[cs] after inv call\\n"); fflush(stderr);
    obf_srand((unsigned int)time(NULL));
    fprintf(stderr, "[cs] after srand\\n"); fflush(stderr);
    shuffle_function(p);
    fprintf(stderr, "[cs] shuffle done\\n"); fflush(stderr);'''

src = src.replace(old, new)
with open(path, 'w', encoding='utf-8') as f:
    f.write(src)
print("more debug added")
