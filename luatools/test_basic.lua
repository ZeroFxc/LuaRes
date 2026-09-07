package.path = '../luatools/?.lua;' .. package.path
local VM = require('vm_gen')
local luac = require('luac')
local vm_pack = require('forward.vm_pack')
local function pack_src(src)
  return vm_pack.pack(luac.undump(string.dec(string.dump(load(src), true)), true))
end
print('=== Test 1: print then global ===')
VM.exec(pack_src('print("hello"); print(type(_G)); print(_G.print and 1 or 0)'))
print('=== Test 2: closure capturing local ===')
VM.exec(pack_src('local x = 5; local function f() return x end; print(f()); print(f())'))
print('=== Test 3: closure with print then upvalue ===')
VM.exec(pack_src('local x = 5; local function f() print("x="); return x end; print(f())'))
print('ALL PASSED')
