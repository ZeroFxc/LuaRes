-- Minimal reproduction of QQ input issue
-- Simulates the license panel input handling

local inputField = 1  -- 1 = key, 2 = QQ
local inputKey = ""
local inputQQ = ""

-- Simulated input state
local mouseX = 300
local mouseY = 200
local mouseClicked = false
local keyPressed = false
local inputChars = ""

-- Stub APIs
ui = {
    draw = {
        get_mouse_pos = function() return {x = mouseX, y = mouseY} end,
        is_mouse_clicked = function(btn)
            if mouseClicked then
                mouseClicked = false  -- consume
                return true
            end
            return false
        end,
        is_key_pressed = function(key)
            if key == 0x09 and keyPressed then  -- TAB
                keyPressed = false
                return true
            end
            return false
        end,
        get_input_characters = function()
            local chars = inputChars
            inputChars = ""
            return chars
        end,
    }
}

local function handleInput()
    -- Field switching via mouse click (simplified)
    if ui.draw.is_mouse_clicked(0) then
        if mouseY > 150 then
            inputField = 2  -- clicked QQ field
        else
            inputField = 1  -- clicked key field
        end
    end

    -- Field switching via TAB
    if ui.draw.is_key_pressed(0x09) then
        inputField = inputField == 1 and 2 or 1
    end

    -- Character input
    local characters = ui.draw.get_input_characters()
    if type(characters) == "string" and characters ~= "" then
        if inputField == 1 then
            local filtered = characters:upper():gsub("[^A-Z0-9%-]", "")
            inputKey = (inputKey .. filtered):sub(1, 80)
        else
            local filtered = characters:gsub("[^0-9]", "")
            inputQQ = (inputQQ .. filtered):sub(1, 20)
        end
    end
end

-- Test 1: Default field is 1, type in key field
print("=== Test 1: Type in default field (key) ===")
inputChars = "ABC123"
handleInput()
print("Field:", inputField, "Key:", inputKey, "QQ:", inputQQ)
assert(inputField == 1, "Field should be 1")
assert(inputKey == "ABC123", "Key should be ABC123, got: " .. inputKey)
print("PASS")

-- Test 2: Click on QQ field, then type
print("\n=== Test 2: Click QQ field, then type digits ===")
mouseClicked = true
mouseY = 200  -- QQ field area
handleInput()  -- consumes click, switches to field 2
print("After click - Field:", inputField)
assert(inputField == 2, "Field should be 2 after click, got: " .. inputField)

inputChars = "12345abc"
handleInput()  -- types digits, filters out abc
print("After type - Field:", inputField, "Key:", inputKey, "QQ:", inputQQ)
assert(inputQQ == "12345", "QQ should be 12345, got: " .. inputQQ)
print("PASS")

-- Test 3: TAB key switching
print("\n=== Test 3: TAB key switching ===")
keyPressed = true
handleInput()  -- consumes TAB, switches to field 1
print("After TAB - Field:", inputField)
assert(inputField == 1, "Field should be 1 after TAB, got: " .. inputField)
print("PASS")

-- Test 4: filesystem.read_file return value handling
print("\n=== Test 4: filesystem.read_file + string match ===")
filesystem = {
    read_file = function(path)
        if path == "test.txt" then
            return "license_key=ABC123\nqq=12345\nbuild_id=test\nwatermark=test"
        end
        return nil
    end
}

local content = filesystem.read_file("test.txt")
print("Content:", content)
assert(content ~= nil, "Content should not be nil")
local licenseKey = content:match("license_key=([^\r\n]+)")
local qq = content:match("qq=([^\r\n]+)")
print("LicenseKey:", licenseKey, "QQ:", qq)
assert(licenseKey == "ABC123", "LicenseKey should be ABC123, got: " .. tostring(licenseKey))
assert(qq == "12345", "QQ should be 12345, got: " .. tostring(qq))
print("PASS")

print("\n=== ALL TESTS PASSED ===")
