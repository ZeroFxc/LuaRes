-- LUnSafe bytecode hot-patch test
local unsafe = require("LUnSafe")
local LASM = unsafe.LASM

-- === Test 1: patch OP_ADD to OP_SUB at runtime ===
local function add(a, b)
    return a + b
end

print("=== Test 1: OP_ADD -> OP_SUB ===")
print("before patch: add(3, 5) =", add(3, 5))
assert(add(3, 5) == 8, "add should be 8")

-- Get Proto pointer from ProtoInfo
local info = LASM.ProtoInfo(add, false)
local proto = info.Proto
print("proto:", proto, "sizecode:", info.sizecode)

-- Traverse instructions, replace OP_ADD(13) with OP_SUB(14)
local patched = 0
LASM.handleInst(proto, function(inst)
    local op = LASM.GET_OPCODE(inst)
    if op == 13 then -- OP_ADD
        patched = patched + 1
        return LASM.SET_OPCODE(inst, 14, false) -- OP_SUB
    end
    return inst
end)
print("patched", patched, "instructions")
assert(patched >= 1, "should patch at least 1 instruction")

print("after patch: add(3, 5) =", add(3, 5))
assert(add(3, 5) == -2, "add should be -2 after patch (3-5)")
print("Test 1 PASSED")
print()

-- === Test 2: patch constant value via replaceK ===
local function getSecret()
    return "original_secret"
end

print("=== Test 2: replace constant string ===")
print("before patch: getSecret() =", getSecret())
assert(getSecret() == "original_secret")

local info2 = LASM.ProtoInfo(getSecret, true) -- detailed to see k table
local proto2 = info2.Proto
print("sizek:", info2.sizek)
for i = 0, info2.sizek - 1 do
    print("  k[" .. i .. "] =", info2.k[i] or "(nil)")
end

-- Find the string constant and replace it
-- k[0] is usually the function name or the string constant
-- Use kindex to read, replaceK to write
for i = 0, info2.sizek - 1 do
    local val = LASM.kindex(proto2, i)
    if val == "original_secret" then
        LASM.replaceK(proto2, i, "patched_secret!")
        print("replaced k[" .. i .. "]")
    end
end

print("after patch: getSecret() =", getSecret())
assert(getSecret() == "patched_secret!", "getSecret should be patched_secret!")
print("Test 2 PASSED")
print()

-- === Test 3: patch return value via constant ===
local function getNum()
    return 42
end

print("=== Test 3: replace number constant ===")
print("before patch: getNum() =", getNum())
assert(getNum() == 42)

local info3 = LASM.ProtoInfo(getNum, false)
local proto3 = info3.Proto
for i = 0, info3.sizek - 1 do
    local val = LASM.kindex(proto3, i)
    if val == 42 then
        LASM.replaceK(proto3, i, 999)
        print("replaced number k[" .. i .. "]")
    end
end

print("after patch: getNum() =", getNum())
assert(getNum() == 999, "getNum should be 999")
print("Test 3 PASSED")
print()

print("ALL HOT-PATCH TESTS PASSED")
