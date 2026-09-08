local f = io.open("_crash_test.luac", "rb")
local d = f:read("*a")
f:close()
print("loaded "..#d.." bytes")
local r, err = load(d)
if not r then print("LOAD FAIL: "..tostring(err)); os.exit(1) end
print("load ok, executing...")
r()
print("EXEC OK")
