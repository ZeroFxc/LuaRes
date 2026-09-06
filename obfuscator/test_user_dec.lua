-- test with user's actual encoded string
local encoded = "=IAPYthkQWr2DFAH7uAABwAAA5BA10aAGv/rgnOiRAABVHdVHBaYIPTaEWXIo58ct8rAmR4b/HSwCMxh6y0N6Ijvz77qwwKTwPrr+F3yxeQYMqYqByxuTCOv3dEFwYGM9Zxd5HOaeqBWcmZS3W+NMRSGfNCcNG4eGTtLJpk7ZV2NrrMxg4M2tL6yClN7Ok/w7PwoCj0yiK986T62VGDlfoOfFFPQBjNC63jZhVU1nwV2GJAI8Vv8K/Ri2ibOO+h8NbKVtUS+qVhzuiC0pbM1w2kyzZEW3isfjFoByLaWPCsmhz8eZXIOKdnzqlQ4uHSIT3Xk+76eGSeKhMdJ4eKxGDwHMje1VjOv7khiLFleR+xu62Xpd7NigTWXuXiQ3Sz2QCazzTzGGie9d0kdE1qYzvt3jg8bR9Wt0GYzrfTKdxE4ZmQXfjX6VfautwIR6GNIxgsKIFuBITsY7nRm2rf9IIUMCk2A+mUza7b4FcAGMKRhv8JKQbgetOZgos7Sh51VxAUEAgcFAEpOBADZLeoCvyA6IGDBcD7b9kCp8lup8mswMSm6HrqMVKV4wZ9dFxOeIj8FAJA5LnC12R0rTm8tHua0ZBd3rodHQBJhdX6EotDHfFNczM2Q44CeJTgBgIscAwH/+J5IYajMq2G9PwAoOTcu9uatKy9ALMBUVUoTgIrLIOmRqkkyO+glcAkMKBMJO4+OBhocJDMnMU9MU/zuTAYoguuKgPU4jWNvDltRDTcDgJFILYOLbHxVWpbft3mGk8nt1fLGHKA4rAKeuBsg54JjmZoHclbX8vK2EgK3Ssgdq+G0ChlI7Z7WDInsKGdpS2kdZEhG5/E1VEIlIi8TCHzN4LPKuObm7eRM3ZpCaeQbvsoG6EurMn6rnHtuMSjPuANPflXPHdcGh+8mTCUhgu51XR5sGruYwo8E0IESbadD28ihKwl0IYXeVFBDiTMjQFOyZzkpbQmIYJcC/uDT6AnFbKQsAOqkTEQ="

print("=== Test 1: direct load (normal) ===")
local ok1, f1 = pcall(load, encoded)
if ok1 then
  f1()
else
  print("LOAD_FAIL:", f1)
end

print("=== Test 2: string.dec then load ===")
local ok, dec = pcall(string.dec, encoded)
if not ok then
  print("DEC_FAIL:", dec)
  return
end
print("dec first byte:", string.byte(dec, 1), "len:", #dec)

local ok2, f2 = pcall(load, dec)
if not ok2 then
  print("LOAD_FAIL:", f2)
  return
end

-- capture output
local old_print = print
local outputs = {}
print = function(...)
  local p = {}
  for i = 1, select('#', ...) do p[i] = tostring(select(i, ...)) end
  table.insert(outputs, table.concat(p, '\t'))
end
local ok3, err = pcall(f2)
print = old_print
if ok3 then
  print("PASS, outputs:", #outputs)
  for i, v in ipairs(outputs) do print("  ", v) end
else
  print("RUN_FAIL:", err)
end
