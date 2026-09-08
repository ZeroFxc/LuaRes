p = r'E:\LuaRes\luaclib\luac_obfuscate.c'
s = open(p, encoding='utf-8').read()

# Fix first pass: handle LOADKX+EXTRAARG pairing
old_first = '''    for (int i = 0; i < n; i++) {
        int op = p->code[i] & 0x3F;
        if (op == LUAC_OP_TFORCALL) {
            group_size[i] = 1;
        } else {
            int brush = 0; /* TEST: 0 */
            /* original + JMP + (extra JMP or random) + brush */
            group_size[i] = 1 + 1 + 1 + brush;
        }
        group_start[i] = total;
        total += group_size[i];
    }'''

new_first = '''    {
        int i = 0;
        while (i < n) {
            int op = p->code[i] & 0x3F;
            if (op == LUAC_OP_TFORCALL) {
                group_size[i] = 1;
                group_start[i] = total;
                total += 1;
                i++;
            } else if (op == LUAC_OP_LOADKX && i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG) {
                /* LOADKX+EXTRAARG must stay consecutive: count as 2 "original" + JMP + extra */
                int brush = 0;
                group_size[i] = 2 + 1 + 1 + brush;
                group_start[i] = total;
                total += group_size[i];
                i++;
                /* EXTRAARG is part of the LOADKX group */
                group_size[i] = 0;
                group_start[i] = group_start[i-1];
                i++;
            } else {
                int brush = 0; /* TEST: 0 */
                group_size[i] = 1 + 1 + 1 + brush;
                group_start[i] = total;
                total += group_size[i];
                i++;
            }
        }
    }'''

s = s.replace(old_first, new_first, 1)

# Fix second pass: emit LOADKX+EXTRAARG together
old_second = '''        if (op == LUAC_OP_TFORCALL) {
            new_code[ni++] = inst;
            continue;
        }

        int brush = group_size[i] - 3; /* original + JMP + extra = 3, rest is brush */
        int logical = IS_LOGICAL(op);'''

new_second = '''        if (op == LUAC_OP_TFORCALL) {
            new_code[ni++] = inst;
            continue;
        }

        if (op == LUAC_OP_LOADKX && i + 1 < n && (p->code[i+1] & 0x3F) == LUAC_OP_EXTRAARG) {
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
        }

        int brush = group_size[i] - 3; /* original + JMP + extra = 3, rest is brush */
        int logical = IS_LOGICAL(op);'''

s = s.replace(old_second, new_second, 1)

open(p, 'w', encoding='utf-8').write(s)
print('LOADKX+EXTRAARG fix applied')
