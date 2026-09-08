p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
s = open(p, encoding='utf-8').read()

# 1. First pass: restore brush for LOADKX group
old1 = '''            } else if (op == LUAC_OP_LOADKX && i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG) {
                /* LOADKX+EXTRAARG must stay consecutive: count as 2 "original" + JMP + extra */
                int brush = 0;
                group_size[i] = 2 + 1 + 1 + brush;'''
new1 = '''            } else if (op == LUAC_OP_LOADKX && i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG) {
                /* LOADKX+EXTRAARG must stay consecutive: count as 2 "original" + JMP + extra */
                int brush = 5 + obf_rand() % 16;
                group_size[i] = 2 + 1 + 1 + brush;'''
s = s.replace(old1, new1, 1)

# 2. First pass: restore brush for normal group
old2 = '''            } else {
                int brush = 0; /* TEST: 0 */
                group_size[i] = 1 + 1 + 1 + brush;'''
new2 = '''            } else {
                int brush = 5 + obf_rand() % 16;
                group_size[i] = 1 + 1 + 1 + brush;'''
s = s.replace(old2, new2, 1)

# 3. Second pass: LOADKX group use brush and random_inst
old3 = '''        if (op == LUAC_OP_LOADKX && i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG) {
            /* emit LOADKX + EXTRAARG consecutively, then JMP + extra */
            new_code[ni++] = inst; /* LOADKX */
            new_code[ni++] = p->code[i+1]; /* EXTRAARG */
            new_code[ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, 1); /* JMP to skip extra */
            if (IS_LOGICAL(op)) {
                new_code[ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, 1);
            } else {
                new_code[ni++] = 0; /* NOP */
            }
            i++; /* skip EXTRAARG in the loop */
            continue;
        }'''
new3 = '''        if (op == LUAC_OP_LOADKX && i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG) {
            /* emit LOADKX + EXTRAARG consecutively, then JMP + extra + brush */
            int brush = group_size[i] - 4; /* 2 original + 1 JMP + 1 extra = 4 */
            int logical = IS_LOGICAL(op);
            new_code[ni++] = inst; /* LOADKX */
            new_code[ni++] = p->code[i+1]; /* EXTRAARG */
            new_code[ni++] = make_jmp(brush + 1); /* JMP to skip extra+brush */
            if (logical) {
                new_code[ni++] = make_jmp(brush + 1); /* extra JMP for logical */
            } else {
                new_code[ni++] = random_inst(); /* garbage */
            }
            for (int j = 0; j < brush; j++) {
                new_code[ni++] = random_inst();
            }
            i++; /* skip EXTRAARG in the loop */
            continue;
        }'''
s = s.replace(old3, new3, 1)

# 4. Second pass: restore extra for normal non-logical
old4 = '''        } else {
            new_code[ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, 0); /* TEST NOP: JMP to next */
        }
        /* brush random garbage */
        for (int j = 0; j < brush; j++) {
            new_code[ni++] = LUAC_AsBx(LUAC_OP_JMP, 0, 0); /* TEST NOP: JMP to next */
        }'''
new4 = '''        } else {
            new_code[ni++] = random_inst();
        }
        /* brush random garbage */
        for (int j = 0; j < brush; j++) {
            new_code[ni++] = random_inst();
        }'''
s = s.replace(old4, new4, 1)

open(p, 'w', encoding='utf-8').write(s)
print('normal parameters restored')
