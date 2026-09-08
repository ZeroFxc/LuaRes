p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
s = open(p, encoding='utf-8').read()

# Add register bounds check after the validation block
old = '''        if (bad_jmp > 0) fprintf(stderr, "[OBF-VALIDATE] %d bad jumps (n=%d ni=%d)\\n", bad_jmp, n, ni);
    }'''

new = '''        if (bad_jmp > 0) fprintf(stderr, "[OBF-VALIDATE] %d bad jumps (n=%d ni=%d)\\n", bad_jmp, n, ni);
    }

    /* register bounds check */
    {
        int bad_reg = 0;
        for (int vi = 0; vi < ni; vi++) {
            unsigned int ins = new_code[vi];
            int vop = ins & 0x3F;
            int va = (ins >> 6) & 0xFF;
            int vb = (ins >> 23) & 0x1FF;
            int vc = (ins >> 14) & 0x1FF;
            if (va >= p->maxstacksize) {
                if (bad_reg < 5) fprintf(stderr, "[OBF-REG] idx=%d op=%d A=%d >= maxstack=%d\\n", vi, vop, va, p->maxstacksize);
                bad_reg++;
            }
            if (vop != 30 && vop != 39 && vop != 40 && vop != 42 && vop != 43 && vop != 44 && vop != 45 && vop != 46 && vop != 47 && vop != 48) {
                if (vb < 256 && vb >= p->maxstacksize) {
                    if (bad_reg < 5) fprintf(stderr, "[OBF-REG] idx=%d op=%d B=%d(reg) >= maxstack=%d\\n", vi, vop, vb, p->maxstacksize);
                    bad_reg++;
                }
                if (vc < 256 && vc >= p->maxstacksize) {
                    if (bad_reg < 5) fprintf(stderr, "[OBF-REG] idx=%d op=%d C=%d(reg) >= maxstack=%d\\n", vi, vop, vc, p->maxstacksize);
                    bad_reg++;
                }
            }
        }
        if (bad_reg > 0) fprintf(stderr, "[OBF-REG] %d register overflows (maxstack=%d)\\n", bad_reg, p->maxstacksize);
    }'''

s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('register check added')
