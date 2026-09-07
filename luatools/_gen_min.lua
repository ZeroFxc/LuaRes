local code = [[
local function risky(x)
  if x < 0 then error("neg:" .. x) end
  return x * 2
end
local ok, err = pcall(risky, -3)
print("pcall result:", ok, err)
print("tostring:", tostring(ok), tostring(err))
]]
local f = load(code)
local bc = string.dec(string.dump(f, true))
local fp = io.open('min_pcall.luac', 'wb')
fp:write(bc)
fp:close()
print('wrote min_pcall.luac', #bc)
