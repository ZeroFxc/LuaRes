local f = function()
    local x = 10
    local inner = function() return x + 5 end
    return inner()
end
local bc = string.dec(string.dump(f))
local out = io.open("tmp_closure.luac", "wb")
out:write(bc)
out:close()
print("Original result:", f())
print("Running flatten...")
os.execute("lua_luac.exe luac_flatten.lua tmp_closure.luac tmp_closure_out.luac")
local f2 = io.open("tmp_closure_out.luac", "rb")
if f2 then
    local flat_bc = f2:read("*a")
    f2:close()
    print("Flattened size:", #flat_bc)
    local flat_func = load(flat_bc)
    if flat_func then
        print("Flattened result:", flat_func())
    else
        print("Load failed!")
    end
else
    print("No output file!")
end
os.remove("tmp_closure.luac")
os.remove("tmp_closure_out.luac")
