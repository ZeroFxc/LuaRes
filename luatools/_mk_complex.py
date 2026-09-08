code = '''print(6)
print("6")
print({6})
print({"6"})
print(true)
print(false)
print(nil)
print(6.6)
print((function (x) return {x} end)(6))
print((function (x) return x end)(6))
print((function() return 6 end)())
print((function (...) return ... end)(6))
print((function (...) return {...} end)(6))
print(#"6")
print(tostring(6).."")
local ver = _VERSION
if ver == "Lua 5.2" then
    print("Lua 5.2")
elseif ver == "Lua 5.3" then
    print("Lua 5.3")
elseif ver == "Lua 5.4" then
    print("Lua 5.4")
else
    print("unknown:", ver)
end
'''
open(r'E:\LuaRes\luatools\_complex.lua', 'w', encoding='utf-8', newline='\n').write(code)
print('done')
