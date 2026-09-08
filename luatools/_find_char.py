s = open(r'E:\LuaRes\a_vm.lua', encoding='utf-8').read()
# Search for string.char, string.byte, or lookup table usage
for keyword in ['string.char', 'string.byte', '_b2c', 'b2c', 'chartab', 'char_table', '_ct', 'lookup', 'K[', 'k[']:
    idx = s.find(keyword)
    if idx >= 0:
        print(f'Found "{keyword}" at {idx}')
        print(repr(s[max(0,idx-100):idx+200]))
        print('---')
