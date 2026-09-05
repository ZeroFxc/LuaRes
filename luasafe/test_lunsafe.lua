-- LUnSafe library test
local ok, unsafe = pcall(require, "LUnSafe")
if not ok then
    print("require LUnSafe failed:", unsafe)
    os.exit(1)
end
print("LUnSafe loaded OK")
print("TypeRead:", type(unsafe.TypeRead))
print("TypeWrite:", type(unsafe.TypeWrite))
print("LASM:", type(unsafe.LASM))

-- Test malloc/free/readmem/writemem
local p = unsafe.malloc(100)
print("malloc(100):", p)
unsafe.writemem(p, 5, "hello")
local s = unsafe.readmem(p, 5)
print("readmem:", s)
assert(s == "hello", "readmem mismatch")
unsafe.free(p)
print("malloc/free/readmem/writemem OK")

-- Test TypeRead/TypeWrite
local p2 = unsafe.malloc(8)
unsafe.TypeWrite.Int(p2, 12345)
local v = unsafe.TypeRead.Int(p2)
print("TypeRead.Int:", v)
assert(v == 12345, "TypeRead.Int mismatch")
unsafe.TypeWrite.Double(p2, 3.14159)
local d = unsafe.TypeRead.Double(p2)
print("TypeRead.Double:", d)
assert(math.abs(d - 3.14159) < 0.0001, "TypeRead.Double mismatch")
unsafe.free(p2)
print("TypeRead/TypeWrite OK")

-- Test luatype2memptr with short string
local short = "abc"
local ptr, sz = unsafe.luatype2memptr(short)
print("short string ptr:", ptr, "size:", sz)
assert(sz == 3, "short string size mismatch")

-- Test luatype2memptr with long string (>40 chars)
local long = string.rep("x", 100)
local ptr2, sz2 = unsafe.luatype2memptr(long)
print("long string ptr:", ptr2, "size:", sz2)
assert(sz2 == 100, "long string size mismatch: got " .. tostring(sz2))

-- Test with number
local ptr3, sz3 = unsafe.luatype2memptr(42)
print("number ptr:", ptr3, "size:", sz3)
assert(sz3 == 8, "number size mismatch")

print("luatype2memptr OK")

-- Test ProtoInfo
local function test_func(a, b)
    return a + b
end
local info = unsafe.LASM.ProtoInfo(test_func, false)
print("ProtoInfo:", type(info))
print("  numparams:", info.numparams)
print("  sizecode:", info.sizecode)
assert(info.numparams == 2, "ProtoInfo numparams mismatch")
print("ProtoInfo OK")

-- Test GET_OPCODE / SET_OPCODE
local ins = unsafe.LASM.SET_OPCODE(0, 1, false) -- OP_LOADK
local op, valid = unsafe.LASM.GET_OPCODE(ins)
print("GET_OPCODE:", op, "valid:", valid)
assert(op == 1, "GET_OPCODE mismatch")
print("GET_OPCODE/SET_OPCODE OK")

print()
print("ALL TESTS PASSED")
