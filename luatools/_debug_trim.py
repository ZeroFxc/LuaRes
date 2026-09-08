p = r'E:\LuaRes\zeus_customer_source_debug.lua'
s = open(p, encoding='utf-8').read()

# Replace trim function with debug version
old_trim = '''local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end'''

new_trim = '''local _trim_pattern = "^%s*(.-)%s*$"
local function trim(value)
    local v = value or ""
    local sv = tostring(v)
    local result = sv:match(_trim_pattern)
    debug_log("trim: input type=" .. type(v) .. " len=" .. #sv .. " input=[" .. sv:sub(1, math.min(#sv, 40)) .. "] result=[" .. tostring(result) .. "]")
    return result or ""
end'''

if old_trim in s:
    s = s.replace(old_trim, new_trim, 1)
    print("Replaced trim with debug version")
else:
    print("ERROR: trim not found")
    idx = s.find('local function trim')
    print(repr(s[idx:idx+150]))

open(p, 'w', encoding='utf-8').write(s)
print("Done, size:", len(s))
