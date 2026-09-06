local f = io.open("E:/LuaRes/web/test_output.luac", "rb")
local bc = f:read("*a")
f:close()
print("Loaded: " .. #bc .. " bytes")
print("Header: " .. string.byte(bc,1) .. " " .. string.byte(bc,2) .. " " .. string.byte(bc,3) .. " " .. string.byte(bc,4))

-- Try to load and run
local func, err = load(bc)
if not func then
    print("LOAD FAIL: " .. tostring(err))
    -- Try with string.dec first
    local dec = string.dec(bc, false)
    print("After dec: " .. #dec .. " bytes")
    func, err = load(dec)
    if not func then
        print("LOAD FAIL after dec: " .. tostring(err))
        os.exit(1)
    end
end
print("Load OK, running...")
func()
print("Run OK!")
