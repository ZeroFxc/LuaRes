-- check_upval: after applying module chain, dump->undump and verify that every
-- child proto's non-instack upvalue idx is within its parent's sizeupvalues
-- (this is exactly pushclosure's encup[idx] bounds at runtime).
local luac = require("luac")
local function rf(p) local f=assert(io.open(p,"rb")); local d=f:read("*a"); f:close(); return d end
local src = rf(arg[1])
local seed = tonumber(arg[3]) or 13
luac.srand(seed)
local proto = luac.undump(string.dec(string.dump(assert(load(src)), true)), false)
for m in arg[2]:gmatch("[^,]+") do
  local ok,e = pcall(luac[m], proto)
  if not ok then io.write("MODERR "..m..": "..tostring(e).."\n"); break end
end
local bc = luac.dump(proto)
local q = luac.undump(bc, false)
local bad = 0
local function chk(pf, depth, name)
  if not pf.p then return end
  for ci = 1, #pf.p do
    local cp = pf.p[ci]
    local ups = cp.upvalues or {}
    local pn = pf.sizeupvalues or 0
    for u = 1, (cp.sizeupvalues or 0) do
      local d = ups[u]
      if d and d.instack == 0 and d.idx >= pn then
        io.write(string.format("BAD %s child#%d depth=%d up[%d] instack=%d idx=%d >= parentNup=%d\n",
              name, ci, depth, u, d.instack, d.idx, pn))
        bad = bad + 1
      end
    end
    chk(cp, depth+1, name.."/c"..ci)
  end
end
chk(q, 0, "main")
io.write("UPVAL CHECK bad="..bad.." mainNup="..tostring(q.sizeupvalues).."\n")
