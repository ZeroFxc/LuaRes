local luac = require("luac")
luac.srand(42)

local f = io.open("../a_vm.lua", "rb")
local src = f:read("*a")
f:close()

local fn = load(src)
local bc = string.dec(string.dump(fn, true))
local p = luac.undump(bc, false)

-- str_encrypt + str_split
luac.str_encrypt_c(p)
print("str_encrypt OK")
luac.str_split_c(p)
print("str_split OK")

-- dump and run
local out_bc = luac.dump(p)
print("dump size:", #out_bc)

-- Save and run
local f2 = io.open("_out_enc_split.luac", "wb")
f2:write(out_bc)
f2:close()

print("=== Running ===")
local fn2, err2 = load(out_bc)
if not fn2 then print("Load error:", err2); os.exit(1) end
local ok, run_err = pcall(fn2)
if not ok then print("Run error:", run_err) else print("Run OK") end
