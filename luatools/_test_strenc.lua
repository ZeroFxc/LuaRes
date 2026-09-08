local luac = require("luac")
luac.srand(42)

local f = io.open("../a_vm.lua", "rb")
local src = f:read("*a")
f:close()

local fn = load(src)
local bc = string.dec(string.dump(fn, true))
local p = luac.undump(bc, false)

-- str_encrypt only
luac.str_encrypt_c(p)
print("str_encrypt OK")

local embedded = luac.vm_embed_c(p, false)
print("Embedded size:", #embedded)

local f2 = io.open("_out_strenc.lua", "wb")
f2:write(embedded)
f2:close()

print("=== Running ===")
local fn2, err2 = load(embedded)
if not fn2 then print("Load error:", err2); os.exit(1) end
local ok, run_err = pcall(fn2)
if not ok then print("Run error:", run_err) else print("Run OK") end
