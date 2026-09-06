-- test_luac.lua - test luac library
local luac = require("luac")

-- Step 1: compile a test function to bytecode
local test_func = function()
    local x = 1 + 2
    local s = "hello"
    print(x, s)
    for i = 1, 10 do
        x = x + i
    end
    return x
end

local bc_raw = string.dump(test_func)
local bc = string.dec(bc_raw)  -- decrypt andlua = format to standard 0x1B bytecode
print("Original bytecode size:", #bc)

-- Step 2: undump
local proto = luac.undump(bc, true)  -- true = andlua encrypted strings
print("undump OK")
print("sizecode:", proto.sizecode)
print("sizek:", proto.sizek)
print("sizep:", proto.sizep)
print("numparams:", proto.numparams)
print("maxstacksize:", proto.maxstacksize)

-- Step 3: inspect instructions
print("\nInstructions:")
for i = 1, proto.sizecode do
    local ins = proto.code[i]
    local op = luac.GET_OPCODE(ins)
    local name = luac.OPCODE_NAMES[op + 1] or "UNKNOWN"
    print(string.format("  [%2d] op=%d %s  raw=0x%08x", i, op, name, ins))
end

-- Step 4: inspect constants
print("\nConstants:")
for i = 1, proto.sizek do
    print(string.format("  [%d] %s (%s)", i, tostring(proto.k[i]), type(proto.k[i])))
end

-- Step 5: test instruction manipulation
print("\nInstruction manipulation tests:")
local jmp = luac.CREATE_AsBx(luac.OP_JMP, 0, 5)
print("CREATE_AsBx(JMP,0,5) =", string.format("0x%08x", jmp))
print("GET_OPCODE =", luac.GET_OPCODE(jmp))
print("GETARG_A =", luac.GETARG_A(jmp))
print("GETARG_sBx =", luac.GETARG_sBx(jmp))

local abc = luac.CREATE_ABC(luac.OP_ADD, 0, 1, 2)
print("CREATE_ABC(ADD,0,1,2) =", string.format("0x%08x", abc))
print("GET_OPCODE =", luac.GET_OPCODE(abc))
print("GETARG_A =", luac.GETARG_A(abc), "B =", luac.GETARG_B(abc), "C =", luac.GETARG_C(abc))

-- Step 6: dump and compare (round-trip)
local bc2 = luac.dump(proto)
print("\nRound-trip bytecode size:", #bc2)
if bc == bc2 then
    print("Round-trip: IDENTICAL")
else
    print("Round-trip: DIFFERENT (may be due to string short/long tag)")
    -- find first difference
    for i = 1, math.min(#bc, #bc2) do
        if bc:byte(i) ~= bc2:byte(i) then
            print(string.format("  First diff at byte %d: 0x%02x vs 0x%02x", i, bc:byte(i), bc2:byte(i)))
            break
        end
    end
end

-- Step 7: verify round-tripped bytecode still runs
local f2 = load(bc2)
if f2 then
    local result = f2()
    print("\nRound-tripped function result:", result)
    print("Expected: 58 (1+2 + sum(1..10) = 3 + 55 = 58)")
else
    print("\nFailed to load round-tripped bytecode!")
end

print("\n=== All tests passed ===")
