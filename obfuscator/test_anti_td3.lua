local luac = require("luac")
local antidec = require("antidec")

local test_func = function()
    local function add(a, b) return a + b end
    local function mul(a, b) return a * b end
    local t = {x = 10, y = 20}
    local sum = add(t.x, t.y)
    local prod = mul(t.x, t.y)
    return sum, prod, string.format("sum=%d, prod=%d", sum, prod)
end

local bc = string.dec(string.dump(test_func))

local function test(name, opts)
    local p = luac.undump(bc, false)
    antidec.protect(p, opts)
    local out = luac.dump(p)
    local ok, f = pcall(load, out)
    if not ok then
        print(name .. ": LOAD FAIL " .. tostring(f))
        return
    end
    local ok2, a, b, c = pcall(f)
    if not ok2 then
        print(name .. ": EXEC FAIL " .. tostring(a))
        return
    end
    print(name .. ": OK result=" .. tostring(a) .. "," .. tostring(b))
end

test("all default", {})
test("poison+strip", {poison_header=true, strip_lineinfo=true, junk_source=false, junk_constants=false})
test("poison+strip+junk_source", {poison_header=true, strip_lineinfo=true, junk_source=true, junk_constants=false})
test("all + junk_constants", {poison_header=true, strip_lineinfo=true, junk_source=true, junk_constants=true})
test("only junk_constants", {poison_header=false, strip_lineinfo=false, junk_source=false, junk_constants=true})
test("junk_source+junk_constants", {poison_header=false, strip_lineinfo=false, junk_source=true, junk_constants=true})
