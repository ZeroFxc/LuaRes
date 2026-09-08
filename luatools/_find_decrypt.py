s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
# Find the decrypt logic - search for BXOR or b2c lookup usage
import re
# Find code around 'b2c' or 'BXOR' or 'concat' or 'GETTABLE'
for keyword in ['b2c', 'BXOR', 'bxor', 'concat', 'CONCAT', 'lookup', '_key', 'byte_char']:
    idx = s.find(keyword)
    if idx >= 0:
        print(f'=== Found "{keyword}" at {idx} ===')
        print(repr(s[max(0,idx-200):idx+300]))
        print()
        break
