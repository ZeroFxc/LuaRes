local luac = require("luac")
local code = [[
print("你好世界")
local s = "测试字符串"
print(s)
print(s .. "后缀")
]]
local function test(mods, label)
    luac.srand(1)
    local p = luac.undump(string.dec(string.dump(load(code), true)), false)
    for _, m in ipairs(mods) do luac[m.."_c"](p) end
    local d = luac.dump(p)
    p = nil
    local r, err = load(d)
    if not r then print(label.." LOAD FAIL: "..tostring(err)); return end
    local old = print
    local out = {}
    print = function(...) out[#out+1]=table.concat({...},"\t") end
    local ok, e = pcall(r)
    print = old
    if not ok then print(label.." EXEC FAIL: "..tostring(e)); return end
    print(label.." => "..table.concat(out, " | "))
end
test({}, "baseline")
test({"str_encrypt"}, "se")
test({"str_split"}, "ss")
test({"vm_embed_c"}, "vm")
test({"str_encrypt","vm_embed_c"}, "se+vm")
test({"str_split","vm_embed_c"}, "ss+vm")
print("DONE")
