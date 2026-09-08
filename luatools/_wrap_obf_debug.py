p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
s = open(p, encoding='utf-8').read()

# Wrap OBF-PRE (single line inside if)
s = s.replace(
    '                fprintf(stderr, "[OBF-PRE] idx=%d op=%d old_sbx=%d target_idx=%d n=%d\\n", i, op, old_sbx, target_idx, n);',
    '#if OBF_DEBUG\n                fprintf(stderr, "[OBF-PRE] idx=%d op=%d old_sbx=%d target_idx=%d n=%d\\n", i, op, old_sbx, target_idx, n);\n#endif'
)

# Wrap OBF-GUARD block (2 lines: if + fprintf)
s = s.replace(
    '''    if (ni != total) fprintf(stderr, "[OBF-GUARD] ni=%d total=%d MISMATCH\\n", ni, total);
    for (int _gi = total; _gi < total + 16; _gi++) {
        if (new_code[_gi] != 0xDEADBEEF) {
            fprintf(stderr, "[OBF-GUARD] overflow at offset %d (word %d): %08x\\n", _gi, _gi - total, new_code[_gi]);
        }
    }''',
    '''#if OBF_DEBUG
    if (ni != total) fprintf(stderr, "[OBF-GUARD] ni=%d total=%d MISMATCH\\n", ni, total);
    for (int _gi = total; _gi < total + 16; _gi++) {
        if (new_code[_gi] != 0xDEADBEEF) {
            fprintf(stderr, "[OBF-GUARD] overflow at offset %d (word %d): %08x\\n", _gi, _gi - total, new_code[_gi]);
        }
    }
#endif'''
)

# Wrap validation block (OBF-BAD, OBF-ORIG-MISALIGNED, OBF-VALIDATE)
# Find the validation block and wrap it
old_val = '''    /* validation: check all ASBX targets */
    {
        int bad_jmp = 0;
        int orig_misaligned = 0;'''
new_val = '''#if OBF_DEBUG
    /* validation: check all ASBX targets */
    {
        int bad_jmp = 0;
        int orig_misaligned = 0;'''
s = s.replace(old_val, new_val, 1)

# Find the end of validation block (after OBF-VALIDATE fprintf)
old_val_end = '''        if (bad_jmp > 0 || orig_misaligned > 0)
            fprintf(stderr, "[OBF-VALIDATE] bad=%d orig_misaligned=%d (n=%d ni=%d)\\n", bad_jmp, orig_misaligned, n, ni);
    }'''
new_val_end = '''        if (bad_jmp > 0 || orig_misaligned > 0)
            fprintf(stderr, "[OBF-VALIDATE] bad=%d orig_misaligned=%d (n=%d ni=%d)\\n", bad_jmp, orig_misaligned, n, ni);
    }
#endif'''
s = s.replace(old_val_end, new_val_end, 1)

# Wrap register bounds check block
old_reg = '''    /* register bounds check */
    {
        int bad_reg = 0;'''
new_reg = '''#if OBF_DEBUG
    /* register bounds check */
    {
        int bad_reg = 0;'''
s = s.replace(old_reg, new_reg, 1)

old_reg_end = '''        if (bad_reg > 0) fprintf(stderr, "[OBF-REG] %d register overflows (maxstack=%d)\\n", bad_reg, p->maxstacksize);
    }'''
new_reg_end = '''        if (bad_reg > 0) fprintf(stderr, "[OBF-REG] %d register overflows (maxstack=%d)\\n", bad_reg, p->maxstacksize);
    }
#endif'''
s = s.replace(old_reg_end, new_reg_end, 1)

open(p, 'w', encoding='utf-8').write(s)
print('debug outputs wrapped in OBF_DEBUG')
