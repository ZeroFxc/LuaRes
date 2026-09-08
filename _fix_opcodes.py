p = r'E:\LuaRes\luaclib\cfg_shuffle.c'
s = open(p, encoding='utf-8').read()

# Fix is_terminator: JMP=30, TFORLOOP=42
s = s.replace(
    'static int is_terminator(int op) {\n    return op == 27 ||  /* JMP */\n           op == 38 ||  /* RETURN */\n           op == 37 ||  /* TAILCALL */\n           op == 39 ||  /* FORLOOP */\n           op == 40 ||  /* FORPREP */\n           op == 43;    /* TFORLOOP */\n}',
    'static int is_terminator(int op) {\n    return op == 30 ||  /* JMP */\n           op == 38 ||  /* RETURN */\n           op == 37 ||  /* TAILCALL */\n           op == 39 ||  /* FORLOOP */\n           op == 40 ||  /* FORPREP */\n           op == 42;    /* TFORLOOP */\n}'
)

# Fix is_conditional: TFORCALL=41
s = s.replace(
    'static int is_conditional(int op) {\n    return op == 31 ||  /* EQ */\n           op == 32 ||  /* LT */\n           op == 33 ||  /* LE */\n           op == 34 ||  /* TEST */\n           op == 35 ||  /* TESTSET */\n           op == 42;    /* TFORCALL (后跟TFORLOOP) */\n}',
    'static int is_conditional(int op) {\n    return op == 31 ||  /* EQ */\n           op == 32 ||  /* LT */\n           op == 33 ||  /* LE */\n           op == 34 ||  /* TEST */\n           op == 35 ||  /* TESTSET */\n           op == 41;    /* TFORCALL (后跟TFORLOOP) */\n}'
)

# Fix JMP sBx fixing: op==27 -> op==30, op==43 -> op==42 (two places)
s = s.replace(
    'if (op == 27 || op == 39 || op == 40 || op == 43) {',
    'if (op == 30 || op == 39 || op == 40 || op == 42) {'
)

# Fix successor analysis: op==27 -> op==30 (JMP), op==43 -> op==42 (FORLOOP/TFORLOOP)
s = s.replace(
    'if (op == 27) {  /* JMP */',
    'if (op == 30) {  /* JMP */'
)
s = s.replace(
    '} else if (op == 39 || op == 43) {  /* FORLOOP / TFORLOOP */',
    '} else if (op == 39 || op == 42) {  /* FORLOOP / TFORLOOP */'
)

# Fix sub function too
s = s.replace(
    'if (op == 27) {\n            int sbx = get_sbx(p->code[last]);',
    'if (op == 30) {\n            int sbx = get_sbx(p->code[last]);'
)
s = s.replace(
    '} else if (op == 39 || op == 43) {\n            int sbx = get_sbx(p->code[last]);\n            int target = last + 1 + sbx;\n            for (int tb = 0; tb < nblocks; tb++) {\n                if (blocks[tb].start == target) {\n                    blocks[b].jmp_target = tb;',
    '} else if (op == 39 || op == 42) {\n            int sbx = get_sbx(p->code[last]);\n            int target = last + 1 + sbx;\n            for (int tb = 0; tb < nblocks; tb++) {\n                if (blocks[tb].start == target) {\n                    blocks[b].jmp_target = tb;'
)

open(p, 'w', encoding='utf-8').write(s)
print('done')
