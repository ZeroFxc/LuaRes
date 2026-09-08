p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
s = open(p, encoding='utf-8').read()

# Replace the validation block with a more detailed one
old = '''    /* validation: check all ASBX targets land at group starts */
    {
        int bad_jmp = 0;
        for (int vi = 0; vi < ni; vi++) {
            int vop = new_code[vi] & 0x3F;
            if (vop == 30 || vop == 39 || vop == 40 || vop == 42) {
                int vsbx = (int)((new_code[vi] >> 14) & 0x3FFFF) - 131071;
                int vtgt = vi + vsbx + 1;
                if (vtgt < 0 || vtgt >= ni) {
                    if (bad_jmp < 5) fprintf(stderr, "[OBF-BAD] idx=%d op=%d sbx=%d target=%d range[0,%d]\\n", vi, vop, vsbx, vtgt, ni-1);
                    bad_jmp++;
                } else {
                    int is_start = 0;
                    for (int gi = 0; gi < n; gi++) {
                        if (group_start[gi] == vtgt) { is_start = 1; break; }
                    }
                    if (!is_start) {
                        if (bad_jmp < 5) fprintf(stderr, "[OBF-MISALIGNED] idx=%d op=%d sbx=%d target=%d\\n", vi, vop, vsbx, vtgt);
                        bad_jmp++;
                    }
                }
            }
        }
        if (bad_jmp > 0) fprintf(stderr, "[OBF-VALIDATE] %d bad jumps (n=%d ni=%d)\\n", bad_jmp, n, ni);
    }'''

new = '''    /* validation: check all ASBX targets */
    {
        int bad_jmp = 0;
        int orig_misaligned = 0;
        for (int vi = 0; vi < ni; vi++) {
            int vop = new_code[vi] & 0x3F;
            if (vop == 30 || vop == 39 || vop == 40 || vop == 42) {
                int vsbx = (int)((new_code[vi] >> 14) & 0x3FFFF) - 131071;
                int vtgt = vi + vsbx + 1;
                /* check if vi is a group start (original instruction position) */
                int is_orig_pos = 0;
                for (int gi = 0; gi < n; gi++) {
                    if (group_start[gi] == vi) { is_orig_pos = 1; break; }
                }
                if (vtgt < 0 || vtgt >= ni) {
                    fprintf(stderr, "[OBF-BAD] idx=%d op=%d sbx=%d target=%d range[0,%d] orig=%d\\n", vi, vop, vsbx, vtgt, ni-1, is_orig_pos);
                    bad_jmp++;
                } else {
                    int is_start = 0;
                    for (int gi = 0; gi < n; gi++) {
                        if (group_start[gi] == vtgt) { is_start = 1; break; }
                    }
                    if (!is_start && is_orig_pos) {
                        /* original instruction's JMP targets non-group-start = BUG */
                        fprintf(stderr, "[OBF-ORIG-MISALIGNED] idx=%d op=%d sbx=%d target=%d\\n", vi, vop, vsbx, vtgt);
                        orig_misaligned++;
                        bad_jmp++;
                    }
                }
            }
        }
        if (bad_jmp > 0 || orig_misaligned > 0)
            fprintf(stderr, "[OBF-VALIDATE] bad=%d orig_misaligned=%d (n=%d ni=%d)\\n", bad_jmp, orig_misaligned, n, ni);
    }'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('validation updated')
