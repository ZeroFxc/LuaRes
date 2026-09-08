local luac = require("luac")
print("vm_embed_c type:", type(luac.vm_embed_c))
print("vm_embed_c:", tostring(luac.vm_embed_c))

-- Test with simple proto
local p = luac.undump(string.dec(string.dump(load("print(1)"), true)), false)
print("proto loaded")
local result = luac.vm_embed_c(p, false)
print("result type:", type(result))
print("result len:", #result)
