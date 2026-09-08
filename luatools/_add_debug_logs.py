import re

p = r'E:\LuaRes\zeus_customer_source_debug.lua'
s = open(p, encoding='utf-8').read()

# 1. Add debug_log helper after the trim function (line 22)
debug_helper = '''
local function debug_log(msg)
    local existing = filesystem.read_file("zeus_debug.log") or ""
    filesystem.write_file("zeus_debug.log", existing .. os.date("%H:%M:%S") .. " " .. tostring(msg) .. "\\n")
end

'''

# Insert after trim function
trim_end = s.find('end\n\nlocal function readLicenseConfig')
if trim_end >= 0:
    s = s[:trim_end+4] + debug_helper + s[trim_end+4:]
    print("Added debug_log helper")
else:
    print("ERROR: Could not find trim function end")

# 2. Add logging to readLicenseConfig
old_readlic = '''local function readLicenseConfig()
    local content = filesystem.read_file("zeus_license.txt")
    if not content then
        return nil, nil, nil, nil
    end
    local licenseKey = trim(content:match("license_key=([^\\r\\n]+)"))
    local qq = trim(content:match("qq=([^\\r\\n]+)"))
    local buildId = trim(content:match("build_id=([^\\r\\n]+)"))
    local watermark = trim(content:match("watermark=([^\\r\\n]+)"))
    if licenseKey == "" or qq == "" or buildId == "" or watermark == "" or licenseKey:find("请填写", 1, true) then
        return nil, nil, nil, nil
    end
    return licenseKey, qq, buildId, watermark
end'''

new_readlic = '''local function readLicenseConfig()
    local content = filesystem.read_file("zeus_license.txt")
    debug_log("readLicenseConfig: content type=" .. type(content) .. " len=" .. tostring(content and #content or 0))
    if not content then
        debug_log("readLicenseConfig: content is nil/false, returning nil")
        return nil, nil, nil, nil
    end
    debug_log("readLicenseConfig: content preview=" .. content:sub(1, math.min(#content, 100)))
    local licenseKey = trim(content:match("license_key=([^\\r\\n]+)"))
    local qq = trim(content:match("qq=([^\\r\\n]+)"))
    local buildId = trim(content:match("build_id=([^\\r\\n]+)"))
    local watermark = trim(content:match("watermark=([^\\r\\n]+)"))
    debug_log("readLicenseConfig: parsed key=" .. tostring(licenseKey) .. " qq=" .. tostring(qq) .. " build=" .. tostring(buildId) .. " wm=" .. tostring(watermark))
    if licenseKey == "" or qq == "" or buildId == "" or watermark == "" or licenseKey:find("请填写", 1, true) then
        debug_log("readLicenseConfig: validation failed, returning nil")
        return nil, nil, nil, nil
    end
    debug_log("readLicenseConfig: success, returning valid config")
    return licenseKey, qq, buildId, watermark
end'''

if old_readlic in s:
    s = s.replace(old_readlic, new_readlic, 1)
    print("Patched readLicenseConfig")
else:
    print("ERROR: Could not find readLicenseConfig")

# 3. Add logging to readLoginConfig
old_readlogin = '''local function readLoginConfig()
    local content = filesystem.read_file("zeus_login.txt")
    if not content then
        return nil, nil
    end
    local licenseKey = trim(content:match("license_key=([^\\r\\n]+)"))
    local qq = trim(content:match("qq=([^\\r\\n]+)"))
    if licenseKey == "" or qq == "" or licenseKey:find("完整卡密", 1, true) or qq:find("自己的QQ", 1, true) then
        return nil, nil
    end
    return licenseKey, qq
end'''

new_readlogin = '''local function readLoginConfig()
    local content = filesystem.read_file("zeus_login.txt")
    debug_log("readLoginConfig: content type=" .. type(content) .. " len=" .. tostring(content and #content or 0))
    if not content then
        debug_log("readLoginConfig: content is nil, returning nil")
        return nil, nil
    end
    local licenseKey = trim(content:match("license_key=([^\\r\\n]+)"))
    local qq = trim(content:match("qq=([^\\r\\n]+)"))
    debug_log("readLoginConfig: parsed key=" .. tostring(licenseKey) .. " qq=" .. tostring(qq))
    if licenseKey == "" or qq == "" or licenseKey:find("完整卡密", 1, true) or qq:find("自己的QQ", 1, true) then
        debug_log("readLoginConfig: validation failed, returning nil")
        return nil, nil
    end
    debug_log("readLoginConfig: success")
    return licenseKey, qq
end'''

if old_readlogin in s:
    s = s.replace(old_readlogin, new_readlogin, 1)
    print("Patched readLoginConfig")
else:
    print("ERROR: Could not find readLoginConfig")

# 4. Add logging to startup auto-read code
old_startup = '''local savedLicenseKey, savedQQ, savedBuildId, savedWatermark = readLicenseConfig()
if savedLicenseKey then
    licenseInputQQ = savedQQ
    verifyZeusLicense(savedLicenseKey, savedQQ, savedBuildId, savedWatermark)
else
    local loginKey, loginQQ = readLoginConfig()
    if loginKey then
        licenseInputKey = loginKey
        licenseInputQQ = loginQQ
        verifyZeusLicense(loginKey, loginQQ, "", "")
    end
end'''

new_startup = '''debug_log("=== STARTUP: beginning auto-read ===")
local savedLicenseKey, savedQQ, savedBuildId, savedWatermark = readLicenseConfig()
debug_log("startup: savedLicenseKey=" .. tostring(savedLicenseKey) .. " savedQQ=" .. tostring(savedQQ))
if savedLicenseKey then
    debug_log("startup: using license config, setting licenseInputQQ=" .. tostring(savedQQ))
    licenseInputQQ = savedQQ
    verifyZeusLicense(savedLicenseKey, savedQQ, savedBuildId, savedWatermark)
else
    debug_log("startup: license config not found, trying login config")
    local loginKey, loginQQ = readLoginConfig()
    debug_log("startup: loginKey=" .. tostring(loginKey) .. " loginQQ=" .. tostring(loginQQ))
    if loginKey then
        debug_log("startup: using login config, setting key=" .. tostring(loginKey) .. " qq=" .. tostring(loginQQ))
        licenseInputKey = loginKey
        licenseInputQQ = loginQQ
        verifyZeusLicense(loginKey, loginQQ, "", "")
    else
        debug_log("startup: no config found, manual input required")
    end
end
debug_log("=== STARTUP: auto-read done, licenseInputKey=" .. tostring(licenseInputKey) .. " licenseInputQQ=" .. tostring(licenseInputQQ) .. " ===")'''

if old_startup in s:
    s = s.replace(old_startup, new_startup, 1)
    print("Patched startup auto-read")
else:
    print("ERROR: Could not find startup code")

# 5. Add logging to drawLicenseInput (mouse click on fields)
old_drawinput = '''    local function drawLicenseInput(field, y, label, value)
        local active = licenseInputField == field
        local border = active and 218 or 65
        ui.draw.text_sz(inputLeft, y - 22.0, label, 14, 185, 190, 200, 255)
        ui.draw.rect_filled(inputLeft, y, inputRight, y + 44.0, 37, 38, 44, 255, 5)
        ui.draw.rect(inputLeft, y, inputRight, y + 44.0, border, active and 35 or 65, active and 58 or 70, 255, 5, 1.0)
        ui.draw.text_sz(inputLeft + 14.0, y + 12.0, value, 16, 235, 235, 240, 255)
        if mouse.x >= inputLeft and mouse.x <= inputRight and mouse.y >= y and mouse.y <= y + 44.0 and ui.draw.is_mouse_clicked(0) then
            licenseInputField = field
        end
    end'''

new_drawinput = '''    local function drawLicenseInput(field, y, label, value)
        local active = licenseInputField == field
        local border = active and 218 or 65
        ui.draw.text_sz(inputLeft, y - 22.0, label, 14, 185, 190, 200, 255)
        ui.draw.rect_filled(inputLeft, y, inputRight, y + 44.0, 37, 38, 44, 255, 5)
        ui.draw.rect(inputLeft, y, inputRight, y + 44.0, border, active and 35 or 65, active and 58 or 70, 255, 5, 1.0)
        ui.draw.text_sz(inputLeft + 14.0, y + 12.0, value, 16, 235, 235, 240, 255)
        local inBounds = mouse.x >= inputLeft and mouse.x <= inputRight and mouse.y >= y and mouse.y <= y + 44.0
        local clicked = ui.draw.is_mouse_clicked(0)
        if inBounds and clicked then
            debug_log("drawLicenseInput: field " .. tostring(field) .. " clicked, switching from " .. tostring(licenseInputField) .. " to " .. tostring(field))
            licenseInputField = field
        end
    end'''

if old_drawinput in s:
    s = s.replace(old_drawinput, new_drawinput, 1)
    print("Patched drawLicenseInput")
else:
    print("ERROR: Could not find drawLicenseInput")

# 6. Add logging to input handling (TAB, backspace, characters)
old_input = '''    if ui.draw.is_key_pressed(0x09) then
        licenseInputField = licenseInputField == 1 and 2 or 1
    end
    if ui.draw.is_key_pressed(0x08) then
        if licenseInputField == 1 then
            licenseInputKey = licenseInputKey:sub(1, -2)
        else
            licenseInputQQ = licenseInputQQ:sub(1, -2)
        end
    end
    local characters = ui.draw.get_input_characters()
    if type(characters) == "string" and characters ~= "" then
        if licenseInputField == 1 then
            local filtered = characters:upper():gsub("[^A-Z0-9%-]", "")
            licenseInputKey = (licenseInputKey .. filtered):sub(1, 80)
        else
            local filtered = characters:gsub("[^0-9]", "")
            licenseInputQQ = (licenseInputQQ .. filtered):sub(1, 20)
        end
    end'''

new_input = '''    local tabPressed = ui.draw.is_key_pressed(0x09)
    if tabPressed then
        debug_log("input: TAB pressed, switching field from " .. tostring(licenseInputField))
        licenseInputField = licenseInputField == 1 and 2 or 1
        debug_log("input: field switched to " .. tostring(licenseInputField))
    end
    if ui.draw.is_key_pressed(0x08) then
        debug_log("input: BACKSPACE pressed, field=" .. tostring(licenseInputField))
        if licenseInputField == 1 then
            licenseInputKey = licenseInputKey:sub(1, -2)
        else
            licenseInputQQ = licenseInputQQ:sub(1, -2)
        end
    end
    local characters = ui.draw.get_input_characters()
    if characters ~= nil and (type(characters) ~= "string" or characters ~= "") then
        debug_log("input: get_input_characters returned type=" .. type(characters) .. " value=" .. tostring(characters and characters:sub(1,50) or nil))
    end
    if type(characters) == "string" and characters ~= "" then
        debug_log("input: processing chars field=" .. tostring(licenseInputField) .. " chars=" .. characters:sub(1,50))
        if licenseInputField == 1 then
            local filtered = characters:upper():gsub("[^A-Z0-9%-]", "")
            licenseInputKey = (licenseInputKey .. filtered):sub(1, 80)
            debug_log("input: key field updated, new len=" .. #licenseInputKey)
        else
            local filtered = characters:gsub("[^0-9]", "")
            licenseInputQQ = (licenseInputQQ .. filtered):sub(1, 20)
            debug_log("input: QQ field updated, new value=" .. licenseInputQQ)
        end
    end'''

if old_input in s:
    s = s.replace(old_input, new_input, 1)
    print("Patched input handling")
else:
    print("ERROR: Could not find input handling")

open(p, 'w', encoding='utf-8').write(s)
print("\nDone! File size:", len(s), "bytes")
