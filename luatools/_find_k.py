s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
idx = s.find('Lua 5.3')
print('Found at', idx)
if idx >= 0:
    print(repr(s[max(0,idx-100):idx+50]))
# Also search for the K array
kidx = s.find('local K =')
if kidx < 0:
    kidx = s.find('K={')
if kidx < 0:
    kidx = s.find('K = {')
print('K array at', kidx)
if kidx >= 0:
    print(repr(s[kidx:kidx+300]))
