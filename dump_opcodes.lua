-- Dump opcode histogram of zeus bytecode
local f = load(io.open('zeus_customer_source_debug.lua', 'r'):read('*a'), '@zeus.lua', 't')
local bc = string.dump(f, false)

-- Parse header and get to the main function
local pos = 1
local function u8() local b = bc:byte(pos); pos = pos + 1; return b end
local function u32()
    local b0,b1,b2,b3 = bc:byte(pos,pos+3); pos = pos + 4
    return b0 | (b1<<8) | (b2<<16) | (b3<<24)
end
local function u64()
    local lo = u32(); local hi = u32()
    return lo + hi * 4294967296
end
local function number_const()
    local bytes = {}
    for i = 1, 8 do bytes[i] = bc:byte(pos); pos = pos + 1 end
    return bytes
end
local function string_const()
    local len = u64()
    if len == 0 then return "" end
    local s = bc:sub(pos, pos + len - 1)
    pos = pos + len
    return s
end

-- Skip header (find the function start)
-- Lua 5.3 header is 19 bytes, but luasafe might be different
-- Just search for the first function by skipping to where sizelineinfo is
pos = 13  -- skip signature+version+format+LUAC_DATA(6)
-- Skip size bytes (int, size_t, Instruction, lua_Integer, lua_Number) = 5 bytes
-- Plus LUAC_INT and LUAC_NUM = 2 bytes
pos = pos + 7
print("Header skip, pos=", pos)

local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG","TBC","NEWARRAY","TFOREACH","SECTION","IS","TRY","TRYRETURN"}

local histogram = {}
local total = 0

local function read_proto(depth)
    -- lineinfo
    local sizelineinfo = u32()
    for i = 1, sizelineinfo do u32() end
    -- locvars
    local sizelocvars = u32()
    for i = 1, sizelocvars do
        string_const(); u32(); u32()
    end
    -- upvalues
    local sizeupvalues = u32()
    for i = 1, sizeupvalues do string_const() end
    -- constants
    local sizek = u32()
    for i = 1, sizek do
        local tt = u8()
        if tt == 1 then -- nil
        elseif tt == 3 then number_const()  -- number
        elseif tt == 4 then u64()  -- integer
        elseif tt == 0x10 then string_const()  -- string
        elseif tt == 0x13 then  -- boolean?
            u8()
        else
            print("Unknown constant type:", tt, "at pos", pos-1)
        end
    end
    -- code
    local sizecode = u32()
    for i = 1, sizecode do
        local ins = u32()
        local op = ins & 0x3F
        histogram[op] = (histogram[op] or 0) + 1
        total = total + 1
    end
    -- sub-protos
    local sizep = u32()
    for i = 1, sizep do read_proto(depth + 1) end
end

read_proto(0)

print("\n=== Opcode Histogram ===")
print("Total instructions:", total)
for op = 0, 60 do
    if histogram[op] then
        local name = opnames[op+1] or ("OP"..op)
        print(string.format("  op=%2d %-12s count=%d (%.1f%%)", op, name, histogram[op], histogram[op]*100/total))
    end
end
print("\n=== Opcodes NOT in standard Lua 5.3 (>=42) ===")
for op = 42, 60 do
    if histogram[op] then
        local name = opnames[op+1] or ("OP"..op)
        print(string.format("  op=%2d %-12s count=%d", op, name, histogram[op]))
    end
end
