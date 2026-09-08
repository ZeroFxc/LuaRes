local luac = require("luac")
luac.srand(42)

-- Step 1: a.lua -> first output
local f = io.open("a.lua", "rb")
local src1 = f:read("*a")
f:close()

local fn1 = load(src1)
local bc1 = string.dec(string.dump(fn1, true))
local p1 = luac.undump(bc1, false)
luac.str_encrypt_c(p1)
luac.str_split_c(p1)
local out1 = luac.vm_embed_c(p1, false)
print("Step1 output size:", #out1)

local f1 = io.open("_first.lua", "wb")
f1:write(out1)
f1:close()

-- Verify step1 runs correctly
local run1, err1 = load(out1)
if not run1 then print("Step1 load error:", err1); os.exit(1) end
local old_print = print
local captured = {}
print = function(...)
    local parts = {}
    for i=1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
    table.insert(captured, table.concat(parts, "\t"))
end
pcall(run1)
print = old_print
print("Step1 run:", table.concat(captured, " | "))

-- Step 2: first output -> second output
local fn2 = load(out1)
local bc2 = string.dec(string.dump(fn2, true))
local p2 = luac.undump(bc2, false)
luac.str_encrypt_c(p2)
luac.str_split_c(p2)
local out2 = luac.vm_embed_c(p2, false)
print("Step2 output size:", #out2)

local f2 = io.open("_second.lua", "wb")
f2:write(out2)
f2:close()

-- Run step2
local run3, err3 = load(out2)
if not run3 then print("Step2 load error:", err3); os.exit(1) end
captured = {}
print = function(...)
    local parts = {}
    for i=1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
    table.insert(captured, table.concat(parts, "\t"))
end
pcall(run3)
print = old_print
print("Step2 run:", table.concat(captured, " | "))
