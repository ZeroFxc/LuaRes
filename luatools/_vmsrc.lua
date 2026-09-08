local luac = require("luac")
local code = [[
print("hello world")
local s = "test string"
print(s)
]]
local function test(mods, label)
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do
        if m == "vm_embed_c" then
            local src = luac.vm_embed_c(p)
            local r, err = load(src)
            if not r then print(label.." LOAD SRC FAIL: "..tostring(err)); return end
            local old = print; local out = {}
            print = function(...) out[#out+1]=table.concat({...},"\t") end
            local ok, e = pcall(r)
            print = old
            if not ok then print(label.." EXEC FAIL: "..tostring(e)); return end
            print(label.." => "..table.concat(out, " | "))
        else
            local fn = luac[m] or luac[m.."_c"]
            fn(p)
        end
    end
end
test({"vm_embed_c"}, "vm")
test({"str_encrypt_c","vm_embed_c"}, "se+vm")
test({"str_split_c","vm_embed_c"}, "ss+vm")
print("DONE")
