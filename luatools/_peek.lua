local src = io.open("_vmout.lua", "r"):read("*a")
local cstart = src:find("code={", 1, true)
print("first 200 chars of code:")
print(src:sub(cstart, cstart+200))
