data = open(r'E:\LuaRes\luatools\_cn_embed.lua', 'r', encoding='utf-8').read()
# find build_proto function
idx = data.find('function build_proto')
if idx < 0:
    idx = data.find('build_proto')
print('build_proto at', idx)
print(data[idx:idx+1500])
