with open(r'E:\LuaRes\luaclib\luac.c', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 找到所有需要包裹的 fprintf 行（调试日志，不是 out of memory 错误）
# 策略：逐行扫描，遇到 fprintf 且不是 "out of memory" 或 "warning: unknown"，
# 检查前一行是否是 #if LUACLIB_DEBUG，如果不是则包裹

result = []
i = 0
in_debug_block = False
debug_block_lines = []

def is_debug_fprintf(line):
    """判断是否是调试 fprintf（需要宏包裹）"""
    if 'fprintf' not in line:
        return False
    # out of memory 是错误日志，不需要宏
    if 'out of memory' in line:
        return False
    # warning: unknown constant tag 是警告，保留（不用宏）
    if 'warning: unknown constant' in line:
        return False
    return True

def flush_debug_block(result, block):
    if not block:
        return
    if len(block) == 1:
        result.append('#if LUACLIB_DEBUG\n')
        result.append(block[0])
        result.append('#endif\n')
    else:
        result.append('#if LUACLIB_DEBUG\n')
        for l in block:
            result.append(l)
        result.append('#endif\n')

while i < len(lines):
    line = lines[i]
    
    # 检查是否已经在 #if LUACLIB_DEBUG 块中
    stripped = line.strip()
    if stripped.startswith('#if LUACLIB_DEBUG'):
        in_debug_block = True
        result.append(line)
        i += 1
        continue
    if in_debug_block and stripped.startswith('#endif'):
        in_debug_block = False
        result.append(line)
        i += 1
        continue
    if in_debug_block:
        result.append(line)
        i += 1
        continue
    
    # 检查是否是调试 fprintf
    if is_debug_fprintf(line):
        # 收集连续的 fprintf 行（包括 for 循环中的 fprintf）
        block = [line]
        j = i + 1
        # 检查下一行是否是 for 循环或连续 fprintf
        while j < len(lines):
            next_line = lines[j]
            next_stripped = next_line.strip()
            # for 循环中的 fprintf
            if next_stripped.startswith('for ') and j+1 < len(lines) and is_debug_fprintf(lines[j+1]):
                block.append(next_line)
                block.append(lines[j+1])
                j += 2
                continue
            # 连续 fprintf
            if is_debug_fprintf(next_line):
                block.append(next_line)
                j += 1
                continue
            break
        flush_debug_block(result, block)
        i = j
    else:
        result.append(line)
        i += 1

with open(r'E:\LuaRes\luaclib\luac.c', 'w', encoding='utf-8') as f:
    f.writelines(result)

# 统计
count = sum(1 for l in result if l.strip() == '#if LUACLIB_DEBUG')
print(f'Wrapped {count} debug blocks')
