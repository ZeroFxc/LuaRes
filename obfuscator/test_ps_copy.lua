local tmp = 'E:/LuaRes/obfuscator/tuoke.lua'
local out = 'C:/Users/ruilo/Downloads/测试输出.luac'
local ps_cmd = 'powershell -NoProfile -Command "Copy-Item -LiteralPath \'' .. tmp .. '\' -Destination \'' .. out .. '\'"'
print('cmd:', ps_cmd)
os.execute(ps_cmd)
print('done')
