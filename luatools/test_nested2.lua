package.path = '../luatools/?.lua;' .. package.path
local VM = require('vm_gen')
local luac = require('luac')
local vm_pack = require('forward.vm_pack')
local function pack_src(src)
  return vm_pack.pack(luac.undump(string.dec(string.dump(load(src), true)), true))
end

-- Test on OUTER VM first
print('=== Outer VM tests ===')
print('anon call:', VM.exec(pack_src('return (function(x) return x*2 end)(21)')))
print('local func:', VM.exec(pack_src('local function f(x) return x*2 end; return f(21)')))
print('upvalue:', VM.exec(pack_src('local x=10; local function f() return x end; return f()')))

-- Create inner VM
local f = loadfile('../luatools/vm_gen.lua')
local bc = string.dec(string.dump(f, true))
local proto = luac.undump(bc, true)
local chunk = vm_pack.pack(proto)
local inner = VM.exec(chunk)

print('=== Inner VM tests ===')
print('anon call:', inner.exec(pack_src('return (function(x) return x*2 end)(21)')))
print('local func:', inner.exec(pack_src('local function f(x) return x*2 end; return f(21)')))
print('upvalue:', inner.exec(pack_src('local x=10; local function f() return x end; return f()')))
print('DONE')
