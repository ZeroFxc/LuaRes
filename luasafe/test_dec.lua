-- test string.dec + load with built-in encryption
local function f()
  print("hello world from dumped function")
  local t = {key = "value"}
  print(t.key)
end

local dumped = string.dump(f)
print("dumped len:", #dumped, "first byte:", string.byte(dumped, 1))

local ok, dec = pcall(string.dec, dumped)
if not ok then
  print("DEC_FAIL:", dec)
  return
end
print("dec len:", #dec, "first byte:", string.byte(dec, 1))

local ok2, func = pcall(load, dec)
if not ok2 then
  print("LOAD_FAIL:", func)
  return
end

print("executing...")
func()
print("DONE")
