-- test C str_encrypt forward + reverse
local luac = require('luac')

local function test(name, src)
    -- compile
    local f = load(src)
    local bc = string.dec(string.dump(f))
    local proto = luac.undump(bc, false)

    -- forward
    local fwd_changes = luac.str_encrypt_c(proto)

    -- dump and run
    local enc_bc = luac.dump(proto)
    local enc_f = load(enc_bc)
    local ok, result = pcall(enc_f)
    if not ok then
        print(string.format("FAIL %s: forward run error: %s", name, result))
        return false
    end

    -- reverse
    local rev_changes = luac.destr_encrypt_c(proto)
    local dec_bc = luac.dump(proto)
    local dec_f = load(dec_bc)
    local ok2, result2 = pcall(dec_f)
    if not ok2 then
        print(string.format("FAIL %s: reverse run error: %s", name, result2))
        return false
    end

    -- compare results
    if tostring(result) ~= tostring(result2) then
        print(string.format("FAIL %s: result mismatch fwd=%s rev=%s", name, tostring(result), tostring(result2)))
        return false
    end

    print(string.format("PASS %-12s fwd=%d rev=%d result=%s", name, fwd_changes, rev_changes, tostring(result)))
    return true
end

local pass = 0
local total = 0

total = total + 1; if test("simple", 'return "hello"') then pass = pass + 1 end
total = total + 1; if test("concat", 'local a="hello" local b="world" return a..b') then pass = pass + 1 end
total = total + 1; if test("table_key", 'local t={a=1} return t.a') then pass = pass + 1 end
total = total + 1; if test("method", 'local t={} function t:f() return "x" end return t:f()') then pass = pass + 1 end
total = total + 1; if test("global", 'return tostring(42)') then pass = pass + 1 end
total = total + 1; if test("settable", 'local t={} t.k="v" return t.k') then pass = pass + 1 end
total = total + 1; if test("long", 'return "this is a very long string for testing encryption purposes"') then pass = pass + 1 end

print(string.format("=== %d pass, %d fail ===", pass, total - pass))
