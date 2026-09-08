local luac = require("luac")
local longstr = string.rep("这是一个很长的测试字符串用于测试分割和加密ABCDEFG123456", 10)
local code = [[
print("]] .. longstr .. [[")
local s = "]] .. longstr .. [["
print(#s)
print(s:sub(1, 20))
local t = {key1 = "value1", key2 = "value2"}
print(t.key1 .. t.key2)
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
            print(label.." => len="..(#out[1] or 0).." #"..out[2].." sub="..out[3].." tbl="..out[4])
        else
            local fn = luac[m] or luac[m.."_c"]
            fn(p)
        end
    end
end
test({"vm_embed_c"}, "vm")
test({"str_encrypt_c","vm_embed_c"}, "se+vm")
test({"str_split_c","vm_embed_c"}, "ss+vm")
test({"str_encrypt_c","str_split_c","vm_embed_c"}, "se+ss+vm")
print("DONE")
