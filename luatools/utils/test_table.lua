local luac = require('luac')
local src = 'local t={a=1,b=2,c=3}; t.d=4; local x=t.a; local y=t["b"]; return x+y+t.c+t.d'
local bc = string.dec(string.dump(load(src)))
local p = luac.undump(bc, false)
local n = luac.table_obfuscate_c(p)
print("changes:", n)
local r = load(luac.dump(p))()
print("result:", r)
print(r == 10 and "PASS" or "FAIL")
