import re
import os

files = [
    r'E:\LuaRes\luaclib\vm_asm\vm_asm.c',
    r'E:\LuaRes\luaclib\vm_asm\vm_asm_loader.c',
    r'E:\LuaRes\luaclib\vm_asm\vm_asm_api.c',
    r'E:\LuaRes\luaclib\vm_asm\vm_asm_stdlib.c',
    r'E:\LuaRes\luaclib\vm_asm\vm_embed.c',
    r'E:\LuaRes\luaclib\vm_asm\vm_asm_mainloop.c',
    r'E:\LuaRes\luaclib\vm_asm\vm_asm_runtime.c',
]

total_removed = 0
for fpath in files:
    with open(fpath, encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    removed = 0
    for line in lines:
        original = line
        # 移除 vmbuf_puts(&b, "-- ...\n"); 整行
        if re.match(r'\s*vmbuf_puts\(&b,\s*"--.*\\n"\s*\);\s*$', line):
            removed += 1
            continue
        # 移除 buf_str(&out, "\n-- ...\n"); 改为 "\n"
        m = re.match(r'(\s*buf_str\(&out,\s*)"\\n--.*\\n"(\s*\);\s*)$', line)
        if m:
            line = m.group(1) + '"\\n"' + m.group(2) + '\n'
            removed += 1
            new_lines.append(line)
            continue
        # 移除 vmbuf_printf 中的 -- %s 注释
        if 'elseif op == %d then  -- %s' in line:
            line = line.replace('elseif op == %d then  -- %s', 'elseif op == %d then')
            removed += 1
        # 移除多行字符串中的Lua注释行（以 "  -- 开头的字符串内容）
        # 例如: "  -- Coroutine: ...\n"
        m = re.match(r'(\s*)"(\s*)--.*\\n"\s*$', line)
        if m and ('vmbuf' in line or 'buf_' in line or line.strip().startswith('"')):
            # 检查是否是C代码注释（/* */），如果是则保留
            if '/*' in line or '*/' in line:
                new_lines.append(line)
                continue
            removed += 1
            continue

        new_lines.append(line)

    with open(fpath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print(f'{os.path.basename(fpath)}: removed {removed} comment lines')
    total_removed += removed

print(f'\nTotal removed: {total_removed} comment lines')
