p = r'E:\LuaRes\zeus_customer_source_debug.lua'
s = open(p, encoding='utf-8').read()

# 1. In readLicenseConfig, add match debug after content preview
old_match = '''    debug_log("readLicenseConfig: content preview=" .. content:sub(1, math.min(#content, 100)))
    local licenseKey = trim(content:match("license_key=([^\\r\\n]+)"))'''

new_match = '''    debug_log("readLicenseConfig: content preview=" .. content:sub(1, math.min(#content, 100)))
    local m1 = content:match("license_key=([^\\r\\n]+)")
    local m2 = content:match("license_key=(.+)")
    debug_log("readLicenseConfig: match1(CRLF pattern)=" .. tostring(m1) .. " match2(dot+)=" .. tostring(m2 and m2:sub(1,50) or nil))
    local licenseKey = trim(content:match("license_key=([^\\r\\n]+)"))'''

if old_match in s:
    s = s.replace(old_match, new_match, 1)
    print("Added match debug in readLicenseConfig")
else:
    print("ERROR: match pattern not found in readLicenseConfig")

# 2. Add field state log at the beginning of the login overlay callback
# Find the drawLicenseInput function definition and add a log before it
old_drawstart = '''    local keyTop = top + 106.0
    local qqTop = top + 174.0
    local function drawLicenseInput(field, y, label, value)'''

new_drawstart = '''    debug_log("login_frame: enter, licenseInputField=" .. tostring(licenseInputField) .. " keyLen=" .. #licenseInputKey .. " qq=" .. licenseInputQQ)
    local keyTop = top + 106.0
    local qqTop = top + 174.0
    local function drawLicenseInput(field, y, label, value)'''

if old_drawstart in s:
    s = s.replace(old_drawstart, new_drawstart, 1)
    print("Added frame enter log")
else:
    print("ERROR: draw start not found")

# 3. Add log after field switch in drawLicenseInput to confirm the write
old_switch = '''        if inBounds and clicked then
            debug_log("drawLicenseInput: field " .. tostring(field) .. " clicked, switching from " .. tostring(licenseInputField) .. " to " .. tostring(field))
            licenseInputField = field
        end'''

new_switch = '''        if inBounds and clicked then
            debug_log("drawLicenseInput: field " .. tostring(field) .. " clicked, switching from " .. tostring(licenseInputField) .. " to " .. tostring(field))
            licenseInputField = field
            debug_log("drawLicenseInput: after set, licenseInputField=" .. tostring(licenseInputField))
        end'''

if old_switch in s:
    s = s.replace(old_switch, new_switch, 1)
    print("Added after-set log")
else:
    print("ERROR: switch not found")

open(p, 'w', encoding='utf-8').write(s)
print("Done, size:", len(s))
