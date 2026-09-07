local luac = require("luac")
local f = loadfile("smoke_target.lua")
local bc = string.dec(string.dump(f, true))

local function test(modules, label)
    local p = luac.undump(bc, false)
    for _, name in ipairs(modules) do
        local fn = luac[name .. '_c']
        if fn then pcall(fn, p) end
    end
    local d = luac.dump(p)
    local r = load(d)
    if r then
        local ok, err = pcall(r)
        print(label .. ": " .. (ok and "OK" or ("FAIL: " .. tostring(err):sub(1,50))))
    else
        print(label .. ": LOAD_FAIL")
    end
end

test({'const_hide','str_encrypt','num_obfuscate','instruction_mutate'}, "ch+se+num+im")
test({'const_hide','const_shuffle','str_encrypt','instruction_mutate'}, "ch+shuffle+se+im")
test({'const_hide','const_shuffle','num_obfuscate','instruction_mutate'}, "ch+shuffle+num+im")
test({'const_hide','const_shuffle','str_encrypt','num_obfuscate','instruction_mutate'}, "all5+im")
