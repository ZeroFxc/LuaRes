path = r'E:\LuaRes\luaclib\opaque_predicate.c'
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

old = '''static unsigned int random_insn(void) {
    int op = obf_rand() % 47;
    int a = obf_rand() % 16;
    int b = obf_rand() % 16;
    int c = obf_rand() % 16;
    if (op == LUAC_OP_RETURN || op == LUAC_OP_CALL || op == LUAC_OP_TAILCALL) op = LUAC_OP_MOVE;
    if (op == LUAC_OP_JMP) return LUAC_AsBx(LUAC_OP_JMP, 0, 1 + (int)(obf_rand() % 5));
    if (op == LUAC_OP_LOADK) return LUAC_ABx(LUAC_OP_LOADK, a, (int)(obf_rand() % 6));
    return LUAC_ABC(op, a, b, c);
}'''

new = '''static unsigned int random_insn(void) {
    /* exclude EXTRAARG(46): must follow LOADKX, orphaned one has garbage Ax
       exclude LOADKX(2): requires EXTRAARG as next instruction
       SETLIST(43) with C=0 also requires EXTRAARG, force C>=1 */
    int op = obf_rand() % 46; /* 0-45, excludes EXTRAARG(46) */
    if (op == LUAC_OP_LOADKX) op = LUAC_OP_LOADK; /* LOADKX needs EXTRAARG follower */
    int a = obf_rand() % 16;
    int b = obf_rand() % 16;
    int c = obf_rand() % 16;
    if (op == LUAC_OP_SETLIST && c == 0) c = 1; /* SETLIST C=0 needs EXTRAARG */
    if (op == LUAC_OP_RETURN || op == LUAC_OP_CALL || op == LUAC_OP_TAILCALL) op = LUAC_OP_MOVE;
    if (op == LUAC_OP_JMP) return LUAC_AsBx(LUAC_OP_JMP, 0, 1 + (int)(obf_rand() % 5));
    if (op == LUAC_OP_LOADK) return LUAC_ABx(LUAC_OP_LOADK, a, (int)(obf_rand() % 6));
    return LUAC_ABC(op, a, b, c);
}'''

if old not in src:
    print("OLD NOT FOUND")
else:
    src = src.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(src)
    print("patched OK")
