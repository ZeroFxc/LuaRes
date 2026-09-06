-- Test string s[i] byte index extension
local s = "Hello"
print("s =", s)
print("s[1] =", s[1], "(expected 72 = 'H')")
print("s[2] =", s[2], "(expected 101 = 'e')")
print("s[5] =", s[5], "(expected 111 = 'o')")
print("s[-1] =", s[-1], "(expected 111 = 'o', last char)")
print("s[-2] =", s[-2], "(expected 108 = 'l')")
print("s[0] =", s[0], "(expected nil)")
print("s[10] =", s[10], "(expected nil)")

assert(s[1] == 72, "s[1] should be 72")
assert(s[2] == 101, "s[2] should be 101")
assert(s[5] == 111, "s[5] should be 111")
assert(s[-1] == 111, "s[-1] should be 111")
assert(s[-2] == 108, "s[-2] should be 108")
assert(s[0] == nil, "s[0] should be nil")
assert(s[10] == nil, "s[10] should be nil")

-- Test standard string functions still work
print()
print("s:upper() =", s:upper())
print("s:len() =", s:len())
print("s:sub(2,4) =", s:sub(2,4))
print("s:find('ell') =", s:find("ell"))

assert(s:upper() == "HELLO", "s:upper() should be HELLO")
assert(s:len() == 5, "s:len() should be 5")
assert(s:sub(2,4) == "ell", "s:sub(2,4) should be ell")

-- Test string metatable with Chinese/multibyte
local cn = "你好"
print()
print("cn =", cn)
print("cn[1] =", cn[1], "(first byte of UTF-8 '你')")
print("cn:len() =", cn:len(), "(byte length)")

print()
print("ALL STRING INDEX TESTS PASSED")
