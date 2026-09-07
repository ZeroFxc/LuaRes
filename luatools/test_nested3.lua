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

print('no-arg func:', inner.exec(pack_src('local function f() return 42 end; return f()')))
print('const return:', inner.exec(pack_src('return (function() return 42 end)()')))
print('identity:', inner.exec(pack_src('return (function(x) return x end)(21)')))
print('DONE')
