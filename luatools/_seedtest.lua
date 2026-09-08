local luac = require("luac")

local function safe_tostring(v)
    if type(v) == 'table' then
        local parts = {}
        for k, vv in pairs(v) do parts[#parts+1] = tostring(k)..'='..tostring(vv) end
        return '{'..table.concat(parts,',')..'}'
    end
    return tostring(v)
end

local function run_test(mods, target_code, seed)
    luac.srand(seed)
    local func = load(target_code)
    local bc = string.dec(string.dump(func, true))
    local p = luac.undump(bc, false)
    for _, m in ipairs(mods) do
        if luac[m.."_c"] then
            local ok, err = pcall(luac[m.."_c"], p)
            if not ok then return false, "MODULE "..m.." ERR: "..tostring(err) end
        end
    end
    local d = luac.dump(p)
    local r, err = load(d)
    if not r then return false, "LOAD FAIL: "..tostring(err) end
    local old = print; local cap = {}
    print = function(...)
        local t = {...}
        local parts = {}
        for i = 1, select('#', ...) do parts[i] = safe_tostring(t[i]) end
        cap[#cap+1] = table.concat(parts, "\t")
    end
    local ok, runerr = pcall(r)
    print = old
    if not ok then return false, "RUN ERR: "..tostring(runerr) end
    return true, table.concat(cap, "|")
end

-- 复现 seed 2/3 失败
local mods = {"str_encrypt","num_obfuscate","opaque_predicate","luac_flatten"}
local target = [[local s='hello' local s2=s..' world' local a=string.upper(s) local b=string.sub(s2,1,5) local c=string.format('x=%d y=%s',42,'ok') print(#s2+#a+#b+#c)]]
for seed = 1, 10 do
    local ok, msg = run_test(mods, target, seed)
    print(string.format("seed=%d %s: %s", seed, ok and "PASS" or "FAIL", msg))
end
print("DONE")
