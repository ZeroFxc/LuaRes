path = r'E:\LuaRes\luaclib\str_encrypt.c'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Replace lines 82-92 (0-indexed 81-91)
# Line 82 (idx 81): fprintf creating decrypt proto
# Line 83 (idx 82): comment
# Line 84 (idx 83): luac_Proto *dec_func = obf_compile_subproto(L, DECRYPT_SRC);
# Line 85 (idx 84): fprintf returned
# Line 86 (idx 85): if (!dec_func) ...
# Line 87 (idx 86): fprintf dec_func created
# Line 88 (idx 87): fflush?
# Line 89 (idx 88): fprintf adding subproto
# Line 90 (idx 89): int dec_idx = ...
# Line 91 (idx 90): fprintf subproto added
# Line 92 (idx 91): int dec_maxstack = ...

new_lines = []
i = 0
while i < len(lines):
    if i == 81:  # line 82, start of decrypt proto section
        new_lines.append('    /* create decrypt proto */\n')
        new_lines.append('    luac_Proto *dec_func = NULL;\n')
        new_lines.append('    if (!obf_compile_subproto(L, DECRYPT_SRC, &dec_func)) return 0;\n')
        new_lines.append('    int dec_idx = obf_add_subproto(L, p, dec_func);\n')
        new_lines.append('    int dec_maxstack = dec_func->maxstacksize ? dec_func->maxstacksize : 12;\n')
        # skip old lines 82-92 (indices 81-91)
        i = 92
        continue
    new_lines.append(lines[i])
    i += 1

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('done')
