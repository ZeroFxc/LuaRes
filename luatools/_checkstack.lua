local luac = require("luac")
local code = [[print(6) print("6") print(true)]]
luac.srand(1)
local p = luac.undump(string.dec(string.dump(load(code), true)), false)
luac.const_hide_c(p); luac.const_shuffle_c(p); luac.str_encrypt_c(p)
luac.num_obfuscate_c(p); luac.opaque_predicate_c(p)
luac.luac_obfuscate_c(p)
io.write("maxstack="..p.maxstacksize.." sizecode="..p.sizecode.."\n"); io.flush()
local maxreg = 0
for i=0,p.sizecode-1 do
    local inst = p.code[i]
    local op = inst % 64
    local a = math.floor(inst / 64) % 256
    if a > maxreg then maxreg = a end
    -- for some ops, B and C can also be registers
    if op ~= 30 and op ~= 39 and op ~= 40 and op ~= 42 and op ~= 1 and op ~= 2 then
        local b = math.floor(inst / 8388608) % 512
        local c = math.floor(inst / 16384) % 512
        if b < 256 and b > maxreg then maxreg = b end
        if c < 256 and c > maxreg then maxreg = c end
    end
end
io.write("highest register used: "..maxreg.."\n"); io.flush()
if maxreg >= p.maxstacksize then
    io.write("WARNING: register "..maxreg.." >= maxstack "..p.maxstacksize.."\n"); io.flush()
end
