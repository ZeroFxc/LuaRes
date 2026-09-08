p = r'E:\LuaRes\zeus_customer_source_debug.lua'
s = open(p, encoding='utf-8').read()

old = 'local function debug_log(msg)\n    local existing = filesystem.read_file("zeus_debug.log") or ""\n    filesystem.write_file("zeus_debug.log", existing .. os.date("%H:%M:%S") .. " " .. tostring(msg) .. "\\n")\nend'
new = 'local _debug_count = 0\nlocal function debug_log(msg)\n    _debug_count = _debug_count + 1\n    local existing = filesystem.read_file("zeus_debug.log") or ""\n    filesystem.write_file("zeus_debug.log", existing .. "[" .. tostring(_debug_count) .. "] " .. tostring(msg) .. "\\n")\nend'

if old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('Fixed: removed os.date, using counter instead')
else:
    print('Pattern not found')
    idx = s.find('debug_log')
    print(repr(s[idx:idx+250]))
