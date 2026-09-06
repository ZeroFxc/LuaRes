package.path = package.path .. ';E:/LuaRes/luatools/forward/?.lua;E:/LuaRes/luatools/?.lua'
local luac = require('luac')
local debug_strip = require('debug_strip')

local input = 'E:/LuaRes/tk.lua'
local output = 'E:/LuaRes/tk_test.luac'

local f = io.open(input, 'rb')
local data = f:read('*a')
f:close()
print('input size:', #data, 'first:', string.byte(data,1))

-- 模拟 menu.lua compile_source 的尝试3
local proto = luac.undump(data, false)
print('undump: main sc='..proto.sizecode..' sk='..#proto.k..' sp='..#proto.p)

-- 只开 debug_strip
debug_strip.strip(proto)
print('after strip: sc='..proto.sizecode..' sk='..#proto.k..' sp='..#proto.p)

local out = luac.dump(proto)
print('output size:', #out)

local f2 = io.open(output, 'wb')
f2:write(out)
f2:close()
print('written to:', output)

-- 测试能否加载
local func, err = load(out)
print('native load:', func and 'OK' or ('FAIL: '..tostring(err)))
