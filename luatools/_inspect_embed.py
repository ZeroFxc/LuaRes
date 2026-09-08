import re
data = open(r'E:\LuaRes\luatools\_cn_embed.lua', 'r', encoding='utf-8').read()
idx = data.find('k={')
if idx >= 0:
    print('k array found at', idx)
    print(data[idx:idx+800])
else:
    print('k={ not found')
    strs = re.findall(r'"[^"]{1,5}"', data[:10000])
    print('Short strings in first 10000 chars:', strs[:30])
