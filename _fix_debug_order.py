p = r'E:\LuaRes\zeus_customer_source_debug.lua'
s = open(p, encoding='utf-8').read()

# Find the trim function and debug_log function, swap them
trim_start = s.find('local _trim_pattern')
debug_start = s.find('local _debug_count = 0')

if trim_start >= 0 and debug_start >= 0 and trim_start < debug_start:
    # Find end of debug_log function
    debug_end = s.find('\n', debug_start)
    # Find the next blank line or next local function after debug_log
    next_section = s.find('\nlocal ', debug_end + 1)
    if next_section < 0:
        next_section = len(s)
    
    trim_block = s[trim_start:debug_start].rstrip() + '\n\n'
    debug_block = s[debug_start:next_section].rstrip() + '\n\n'
    
    s = s[:trim_start] + debug_block + trim_block + s[next_section:]
    open(p, 'w', encoding='utf-8').write(s)
    print('Fixed: moved debug_log before trim')
else:
    print(f'trim_start={trim_start}, debug_start={debug_start}')
    if trim_start >= 0 and debug_start >= 0:
        print('Already in correct order' if debug_start < trim_start else 'Wrong order')
