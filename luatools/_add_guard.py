p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
s = open(p, encoding='utf-8').read()

old = '    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * total);'
new = '''    unsigned int *new_code = (unsigned int *)malloc(sizeof(unsigned int) * (total + 16));
    for (int _gi = total; _gi < total + 16; _gi++) new_code[_gi] = 0xDEADBEEF;'''
s = s.replace(old, new)

old2 = '    free(p->code);'
new2 = '''    if (ni != total) fprintf(stderr, "[OBF-GUARD] ni=%d total=%d MISMATCH\\n", ni, total);
    for (int _gi = total; _gi < total + 16; _gi++) {
        if (new_code[_gi] != 0xDEADBEEF) {
            fprintf(stderr, "[OBF-GUARD] overflow at offset %d (word %d): %08x\\n", _gi, _gi - total, new_code[_gi]);
        }
    }
    free(p->code);'''
s = s.replace(old2, new2)

open(p, 'w', encoding='utf-8').write(s)
print('guard added')
