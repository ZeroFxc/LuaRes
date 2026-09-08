local f = load('local v = "ZEUS-123"\nlocal x = v or ""\nprint("result:", x)\n')
local bc = string.dump(f, false)

-- Parse bytecode header
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
local function number()
    -- Lua 5.3 uses double (8 bytes) for numbers by default
    local bytes = {}
    for i = 1, 8 do bytes[i] = bc:byte(pos); pos = pos + 1 end
    -- Convert to double (little-endian IEEE 754)
    local sign = bytes[8] >> 7
    local exp = ((bytes[8] & 0x7F) << 4) | (bytes[7] >> 4)
    local mant = 0
    for i = 7, 1, -1 do mant = mant * 256 + bytes[i] end
    mant = mant & 0xFFFFFFFFFFFFF
    if exp == 0 then return 0
    elseif exp == 0x7FF then return sign == 0 and math.huge or -math.huge
    else
        mant = mant + 0x10000000000000
        return (sign == 0 and 1 or -1) * mant * 2^(exp - 1023 - 52)
    end
end
local function string_const()
    local len = u64()
    if len == 0 then return "" end
    local s = bc:sub(pos, pos + len - 1)
    pos = pos + len
    return s
end

-- Header
print("Header:", bc:byte(1), bc:byte(2), bc:byte(3), bc:byte(4))
pos = 13  -- skip header (12 bytes + 1 version byte)
-- Actually let me just skip to the function
-- Lua 5.3 header: 4 (signature) + 1 (version) + 1 (format) + 6 (LUAC_DATA) + 1 (instruction size) + 1 (int size) + 1 (size_t size) + 1 (instruction enum) + 1 (float enum) = 17 bytes
pos = 18
print("Skipped header, pos=", pos)

-- Function prototype
local function read_proto()
    local sizelineinfo = u32()
    for i = 1, sizelineinfo do u32() end  -- lineinfo
    local sizelocvars = u32()
    for i = 1, sizelocvars do
        string_const(); u32(); u32()  -- locvar
    end
    local sizeupvalues = u32()
    for i = 1, sizeupvalues do string_const() end  -- upvalue names
    local sizek = u32()
    local k = {}
    for i = 1, sizek do
        local tt = u8()
        if tt == 1 then k[i] = {type="nil"}
        elseif tt == 3 then k[i] = {type="number", val=number()}
        elseif tt == 4 then k[i] = {type="integer", val=u64()}
        elseif tt == 0x10 then k[i] = {type="string", val=string_const()}
        else k[i] = {type="unknown:"..tt}
        end
    end
    local sizecode = u32()
    local code = {}
    for i = 1, sizecode do
        code[i] = u32()
    end
    local sizep = u32()
    local p = {}
    for i = 1, sizep do p[i] = read_proto() end
    return {k=k, code=code, p=p}
end

local proto = read_proto()
print("Constants:")
for i, v in ipairs(proto.k) do
    print(string.format("  K[%d] = %s %s", i-1, v.type, v.val or ""))
end
print("Instructions:")
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}
for i, ins in ipairs(proto.code) do
    local op = ins & 0x3F
    local a = (ins >> 6) & 0xFF
    local c = (ins >> 14) & 0x1FF
    local b = (ins >> 23) & 0x1FF
    local bx = ins >> 14
    local sbx = bx - 131071
    local name = opnames[op+1] or ("OP"..op)
    print(string.format("  [%d] %-12s A=%d B=%d C=%d bx=%d sbx=%d (ins=0x%08X)", i-1, name, a, b, c, bx, sbx, ins))
end
