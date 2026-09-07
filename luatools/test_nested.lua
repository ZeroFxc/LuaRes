package.path = '../luatools/?.lua;' .. package.path
local VM = require('vm_gen')
local luac = require('luac')
local vm_pack = require('forward.vm_pack')
local function pack_src(src)
  return vm_pack.pack(luac.undump(string.dec(string.dump(load(src), true)), true))
end
local f = loadfile('../luatools/vm_gen.lua')
local bc = string.dec(string.dump(f, true))
local proto = luac.undump(bc, true)
local chunk = vm_pack.pack(proto)
local inner = VM.exec(chunk)

-- Test 1: pure arithmetic (no _ENV, no calls)
print('Test 1: return 6*7')
print('  result:', inner.exec(pack_src('return 6*7')))

-- Test 2: local function call (no _ENV)
print('Test 2: local function call')
print('  result:', inner.exec(pack_src('local function f(x) return x*2 end; return f(21)')))

-- Test 3: function with upvalue
print('Test 3: closure with upvalue')
print('  result:', inner.exec(pack_src('local x=10; local function f() return x end; return f()')))

-- Test 4: print (uses _ENV)
print('Test 4: print')
inner.exec(pack_src('print(42)'))
print('  done')
