-- Analyze all anomalies in fangtd.lua that could confuse TD decompiler
local luac = require("luac")

local f = io.open("E:/LuaRes/fangtd.lua", "rb")
local data = f:read("*a")
f:close()

print("=== File size: " .. #data .. " bytes ===")

-- Check header byte by byte
print("\n=== Header analysis ===")
local hdr = {}
for i = 1, 33 do hdr[i] = data:byte(i) end
print("signature: " .. string.char(hdr[1]) .. string.char(hdr[2]) .. string.char(hdr[3]) .. string.char(hdr[4]))
print("version: 0x" .. string.format("%02X", hdr[5]) .. " (5.3=0x53)")
print("format: 0x" .. string.format("%02X", hdr[6]))
print("endianness: 0x" .. string.format("%02X", hdr[7]))
print("sizeof(int): " .. hdr[8])
print("sizeof(size_t): " .. hdr[9])
print("sizeof(Instruction): " .. hdr[10])
print("sizeof(lua_Integer): " .. hdr[11])
print("sizeof(lua_Number): " .. hdr[12])
print("LUAC_INT check:")
for i = 13, 20 do io.write(string.format("%02X ", hdr[i])) end
print()
print("LUAC_NUM check:")
for i = 21, 28 do io.write(string.format("%02X ", hdr[i])) end
print()
print("upvalue count byte (byte 34): " .. data:byte(34))

-- Undump and analyze main function
local p = luac.undump(data, false)
print("\n=== Main function header ===")
print("source: " .. tostring(p.source))
print("linedefined: " .. p.linedefined)
print("lastlinedefined: " .. p.lastlinedefined)
print("numparams: " .. p.numparams .. " (normal main=0)")
print("is_vararg: " .. p.is_vararg .. " (normal main=0 or 1)")
print("maxstacksize: " .. p.maxstacksize .. " (normal=2-10)")
print("sizecode: " .. #p.code)
print("sizek: " .. #p.k)
print("sizep: " .. #p.p)
print("sizeupvalues: " .. p.sizeupvalues)
print("sizelineinfo: " .. #p.lineinfo)
print("sizelocvars: " .. #p.locvars)

-- Check if lineinfo count matches code count
print("\n=== lineinfo vs code mismatch ===")
print("main: lineinfo=" .. #p.lineinfo .. " code=" .. #p.code .. " match=" .. tostring(#p.lineinfo == #p.code))

-- Scan all functions for anomalies
print("\n=== Scanning all 10354 functions for anomalies ===")
local anomalies = {
    numparams_gt_20 = 0,
    is_vararg_gt_2 = 0,
    maxstack_gt_100 = 0,
    maxstack_gt_250 = 0,
    lineinfo_mismatch = 0,
    zero_code = 0,
    huge_code = 0,
    source_nonnil = 0,
}
local total = 0
local function scan(pp)
    total = total + 1
    if pp.numparams > 20 then anomalies.numparams_gt_20 = anomalies.numparams_gt_20 + 1 end
    if pp.is_vararg > 2 then anomalies.is_vararg_gt_2 = anomalies.is_vararg_gt_2 + 1 end
    if pp.maxstacksize > 100 then anomalies.maxstack_gt_100 = anomalies.maxstack_gt_100 + 1 end
    if pp.maxstacksize > 250 then anomalies.maxstack_gt_250 = anomalies.maxstack_gt_250 + 1 end
    if #pp.lineinfo ~= #pp.code then anomalies.lineinfo_mismatch = anomalies.lineinfo_mismatch + 1 end
    if #pp.code == 0 then anomalies.zero_code = anomalies.zero_code + 1 end
    if #pp.code > 10000 then anomalies.huge_code = anomalies.huge_code + 1 end
    if pp.source and pp.source ~= "" then anomalies.source_nonnil = anomalies.source_nonnil + 1 end
    for i = 1, #pp.p do scan(pp.p[i]) end
end
scan(p)

print("total functions: " .. total)
for k, v in pairs(anomalies) do
    if v > 0 then print("  " .. k .. ": " .. v) end
end

-- Check the first few instructions of main
print("\n=== Main function first 10 instructions ===")
for i = 1, math.min(10, #p.code) do
    local op = p.code[i] % 64
    io.write(string.format("  [%d] opcode=%d raw=0x%08X\n", i, op, p.code[i]))
end

-- Check constants of main
print("\n=== Main function constants ===")
for i = 1, math.min(20, #p.k) do
    local v = p.k[i]
    io.write(string.format("  [%d] type=%s value=%s\n", i, type(v), tostring(v)))
end
